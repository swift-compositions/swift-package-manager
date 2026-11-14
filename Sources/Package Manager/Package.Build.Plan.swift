public import File_System
internal import Kernel
internal import Msgpack_Org_Messagepack
public import SPM_Standard

extension Package.Build {

    public struct Plan: Sendable, Equatable {

        public let compiles: [Swift.String: Step]

        public let links: [Swift.String: Step]

        public let signatures: [Swift.String: Step]

        public init(commands: [[Swift.String]], directory: File.Directory) {
            var compiles: [Swift.String: Step] = [:]
            var links: [Swift.String: Step] = [:]
            var signatures: [Swift.String: Step] = [:]
            for command in commands {
                guard let first = command.first else { continue }
                if first == "builtin-SwiftDriver", command.count > 2, command[1] == "--" {
                    let arguments = Swift.Array(command.dropFirst(2))
                    let draft = Step(directory: directory, arguments: arguments)
                    guard let module = draft.value(after: "-module-name") else { continue }
                    compiles[module] = Step(
                        directory: Self.directory(draft.value(after: "-working-directory")) ?? directory,
                        arguments: arguments
                    )
                } else if Self.components(first).last == "codesign", command.count > 1, let signed = command.last {
                    signatures[signed] = Step(directory: directory, arguments: command)
                } else {
                    let step = Step(directory: directory, arguments: command)
                    guard let output = step.output else { continue }
                    links[output] = step
                }
            }
            self.compiles = compiles
            self.links = links
            self.signatures = signatures
        }
    }
}

extension Package.Build.Plan {

    public func replay(
        changed paths: [Swift.String],
        product: Swift.String,
        timeout: Swift.Duration = .seconds(600)
    ) throws(Package.Build.Error) -> Package.Build.Replay {
        let started = ContinuousClock.now
        var sources: [Swift.String: Set<Swift.String>] = [:]
        for (module, step) in compiles {
            sources[module] = Self.sources(of: step)
        }
        var canonical: [Swift.String: Set<Swift.String>]?
        var modules: Set<Swift.String> = []
        for path in paths {
            let names = [path, Self.canonical(path)].compactMap { $0 }
            var holders = sources.filter { !$0.value.isDisjoint(with: names) }.keys.map { $0 }
            if holders.isEmpty {
                let resolved = canonical ?? sources.mapValues { Set($0.compactMap(Self.canonical)) }
                canonical = resolved
                holders = resolved.filter { !$0.value.isDisjoint(with: names) }.keys.map { $0 }
            }
            guard !holders.isEmpty else { return .refused(.unlisted(path: path)) }
            modules.formUnion(holders)
        }
        guard let output = self.output(of: product), let link = links[output] else {
            return .refused(.unlinked(product: product))
        }
        let ordered = modules.sorted()
        for module in ordered {
            guard let step = compiles[module] else { continue }
            let interface = step.value(after: "-emit-module-path")
            let before = interface.flatMap(Self.contents(of:))
            do throws(Package.Build.Error) {
                try step.run(timeout: timeout)
            } catch {
                guard case .failed(_, let termination, let stdout, let stderr) = error else { throw error }
                throw .compile(module: module, termination: termination, stdout: stdout, stderr: stderr)
            }
            let after = interface.flatMap(Self.contents(of:))
            guard before != nil, before == after else {
                return .refused(.interface(module: module))
            }
            if let merge = self.merge(of: step) {
                try merge.run(timeout: timeout)
            }
        }
        try link.run(timeout: timeout)
        try signatures[output]?.run(timeout: timeout)
        return .rebuilt(modules: ordered, product: output, duration: started.duration(to: ContinuousClock.now))
    }
}

extension Package.Build.Plan {

    internal func output(of product: Swift.String) -> Swift.String? {
        links.keys
            .filter { path in
                let components = Self.components(path)
                return components.last == product[...] && components.dropLast(2).last == "Products"
            }
            .min()
    }

    internal func merge(of compile: Package.Build.Step) -> Package.Build.Step? {
        guard let map = compile.value(after: "-output-file-map") else { return nil }
        let directory = Self.parent(map)
        return links.values
            .filter { step in step.links.map(Self.parent) == directory }
            .min { ($0.output ?? "") < ($1.output ?? "") }
    }

    internal static func directory(_ path: Swift.String?) -> File.Directory? {
        guard let path else { return nil }
        do throws(File.Path.Error) {
            return File.Directory(try File.Path(path))
        } catch {
            return nil
        }
    }

    internal static func canonical(_ path: Swift.String) -> Swift.String? {
        do throws(File.Path.Error) {
            let location = try File.Path(path)
            do throws(File.System.Canonical.Error) {
                return try File.System.Canonical.resolve(location).string
            } catch {
                return nil
            }
        } catch {
            return nil
        }
    }

    internal static func components(_ path: Swift.String) -> [Swift.Substring] {
        path.split(whereSeparator: { $0 == "/" || $0 == "\\" })
    }

    internal static func parent(_ path: Swift.String) -> Swift.Substring {
        guard let separator = path.lastIndex(where: { $0 == "/" || $0 == "\\" }) else { return "" }
        return path[..<separator]
    }

    internal static func sources(of step: Package.Build.Step) -> Set<Swift.String> {
        guard let list = step.list(".SwiftFileList"), let bytes = contents(of: list) else { return [] }
        let text = Swift.String(decoding: bytes, as: UTF8.self)
        var paths: Set<Swift.String> = []
        for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            let path = unescaped(line)
            if !path.isEmpty { paths.insert(path) }
        }
        return paths
    }

    internal static func unescaped(_ line: Swift.Substring) -> Swift.String {
        var characters = line[...]
        if characters.count >= 2, let quote = characters.first, quote == "\"" || quote == "'",
            characters.last == quote
        {
            characters = characters.dropFirst().dropLast()
        }
        #if os(Windows)
            return Swift.String(characters)
        #else
            var path = ""
            var escaped = false
            for character in characters {
                if escaped {
                    path.append(character)
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else {
                    path.append(character)
                }
            }
            return path
        #endif
    }

    internal static func contents(of path: Swift.String) -> [UInt8]? {
        let location: File.Path
        do throws(File.Path.Error) {
            location = try File.Path(path)
        } catch {
            return nil
        }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(location).read.full { bytes in
                var contents = [UInt8]()
                contents.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    contents.append(bytes[index].bitPattern)
                }
                return contents
            }
        } catch {
            return nil
        }
    }
}
extension Package.Build.Plan {

    public init?(
        product: Swift.String,
        at directory: File.Directory,
        scratch: Swift.String? = nil,
        configuration: Package.Build.Configuration = .debug
    ) {
        let root: File.Directory
        do throws(Package.Manager.Error) {
            root = try Package.Manager.scratch(scratch, in: directory)
        } catch {
            return nil
        }
        let out = root / File.Path.Component(unchecked: "out")
        let intermediates = out / File.Path.Component(unchecked: "Intermediates.noindex")
        let data = intermediates / File.Path.Component(unchecked: "XCBuildData")
        let entries: [File.Directory.Entry]
        do throws(File.Directory.Contents.Error) {
            entries = try File.Directory.Contents.list(at: data)
        } catch {
            return nil
        }
        let history = (data / File.Path.Component(unchecked: "prior-build-descriptions.txt")).path
        let used = Swift.String(decoding: Self.contents(of: history.string) ?? [], as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0 + ".xcbuilddata" }
        let found = entries.compactMap { entry -> (path: File.Path, modified: Kernel.Time, used: Int)? in
            guard let name = Swift.String(entry.name), name.hasSuffix(".xcbuilddata"),
                let path = entry.pathIfValid
            else { return nil }
            let store = (File.Directory(path) / File.Path.Component(unchecked: "task-store.msgpack")).path
            do throws(Kernel.File.Stats.Error) {
                return (store, try File(store).stat.info.modificationTime, used.lastIndex { $0 == name } ?? -1)
            } catch {
                return nil
            }
        }
        let stores = found.sorted { $0.used == $1.used ? $0.modified > $1.modified : $0.used > $1.used }
        for store in stores {
            guard let bytes = Self.contents(of: store.path.string),
                let commands = Self.commands(in: bytes.map { Byte(bitPattern: $0) })
            else { continue }
            let plan = Package.Build.Plan(commands: commands, directory: directory)
            guard let output = plan.output(of: product),
                Self.components(output).dropLast().last.map(Swift.String.init) == configuration.directory
            else { continue }
            self = plan
            return
        }
        return nil
    }
}

extension Package.Build.Plan {

    internal static func commands(in bytes: [Byte]) -> [[Swift.String]]? {
        var reader = Msgpack.Reader(bytes)
        var commands: [[Swift.String]] = []
        var pending: Msgpack.Token?
        do throws(Msgpack.Error) {
            while true {
                let current: Msgpack.Token
                if let token = pending {
                    current = token
                    pending = nil
                } else if let token = try reader.next() {
                    current = token
                } else {
                    break
                }
                guard case .array(let count) = current, count >= 2 else { continue }
                var strings: [Swift.String] = []
                while strings.count < Int(count), let token = try reader.next() {
                    guard case .string(let range) = token else {
                        pending = token
                        break
                    }
                    strings.append(text(reader.bytes[range]))
                }
                guard pending == nil, strings.count == Int(count) else { continue }
                if strings[0] == "builtin-SwiftDriver" {
                    commands.append(strings)
                    continue
                }
                guard strings[0] == "Ld" || strings[0] == "CodeSign" else { continue }
                var header = try reader.next()
                while case .string = header {
                    header = try reader.next()
                }
                guard case .array(let total) = header else {
                    pending = header
                    continue
                }
                var arguments: [Swift.String] = []
                elements: while arguments.count < Int(total), let token = try reader.next() {
                    guard token == .array(count: 2) else {
                        pending = token
                        break
                    }
                    while let token = try reader.next() {
                        switch token {
                        case .signed, .unsigned:
                            continue

                        case .binary(let range):
                            arguments.append(text(reader.bytes[range]))
                            continue elements

                        default:
                            pending = token
                            break elements
                        }
                    }
                }
                if pending == nil, arguments.count == Int(total), !arguments.isEmpty {
                    commands.append(arguments)
                }
            }
        } catch {
            return nil
        }
        return commands
    }

    private static func text(_ bytes: Swift.ArraySlice<Byte>) -> Swift.String {
        Swift.String(decoding: bytes.lazy.map(\.bitPattern), as: UTF8.self)
    }
}
