internal import FIPS_180_4
public import File_System
internal import JSON
internal import Process
public import SPM_Standard

extension Package {

    public struct Manager: Sendable {
        public let executable: Swift.String

        public init(executable: Swift.String = Package.Manager.launcher) {
            self.executable = executable
        }
    }
}

extension Package.Manager {

    public static var launcher: Swift.String {
        #if os(Windows)
            "C:\\Windows\\System32\\cmd.exe"
        #else
            "/usr/bin/env"
        #endif
    }

    internal var launcherPrefix: [Swift.String] {
        guard executable == Package.Manager.launcher else { return [] }
        #if os(Windows)
            return ["/c", "swift"]
        #else
            return ["swift"]
        #endif
    }
}

extension Package.Manager {
    public func catalog(
        at directory: File.Directory,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Catalog {
        let before = try manifestSource(at: directory)
        let toolchain = try toolchain(timeout: timeout)
        let evaluation = try evaluation(
            at: directory,
            timeout: timeout,
            scratch: scratch
        )
        let after = try manifestSource(at: directory)
        guard before == after else {
            throw .manifestChanged(directory: directory.path.string)
        }
        return .init(
            manifest: FIPS_180_4.SHA256.digest(before).hex,
            toolchain: FIPS_180_4.SHA256.digest(toolchain).hex,
            evaluation: evaluation
        )
    }

    private func manifestSource(
        at directory: File.Directory
    ) throws(Error) -> [Byte] {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try directory[file: "Package.swift"].read.full { bytes in
                var source = [Byte]()
                source.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    source.append(bytes[index])
                }
                return source
            }
        } catch {
            throw .manifestUnavailable(directory: directory.path.string)
        }
    }
}

extension Package.Manager {

    internal func dump(
        at directory: File.Directory,
        timeout: Swift.Duration,
        scratch: Swift.String?
    ) throws(Error) -> JSON {
        var arguments = launcherPrefix + ["package"]
        if let scratch {
            arguments.append(contentsOf: ["--scratch-path", scratch])
        }
        arguments.append("dump-package")
        let output: Process.Output
        let started = ContinuousClock.now
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    directory: directory.path,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }

        if Self.expired(output.status, since: started, timeout: timeout) {
            throw .timedOut(directory: directory.path.string)
        }
        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
        guard let bytes = output.stdout else {
            throw .output
        }

        do throws(JSON.Error) {
            return try JSON.parse(Swift.String(decoding: bytes, as: UTF8.self))
        } catch {
            throw .manifest
        }
    }

    internal static func expired(
        _ status: Process.Status,
        since started: ContinuousClock.Instant,
        timeout: Swift.Duration
    ) -> Swift.Bool {
        guard case .signaled = status else { return false }
        return started.duration(to: ContinuousClock.now) >= timeout
    }

    internal func termination(_ status: Process.Status) -> Termination {
        switch status {
        case .exited(let code): .exited(code: code)
        case .signaled(let signal): .signaled(signal: signal)
        case .stopped(let signal): .stopped(signal: signal)
        }
    }
}

extension Package.Manager {

    public func edit(
        _ identity: Swift.String,
        path: File.Path,
        at directory: File.Directory,
        timeout: Swift.Duration = .seconds(120)
    ) throws(Error) {
        try run(["package", "edit", identity, "--path", path.string], at: directory, timeout: timeout)
    }

    public func unedit(
        _ identity: Swift.String,
        at directory: File.Directory,
        force: Swift.Bool = false,
        timeout: Swift.Duration = .seconds(120)
    ) throws(Error) {
        try run(
            force
                ? ["package", "unedit", "--force", identity]
                : ["package", "unedit", identity],
            at: directory,
            timeout: timeout
        )
    }
}

extension Package.Manager {

    private func run(
        _ arguments: [Swift.String],
        at directory: File.Directory,
        timeout: Swift.Duration
    ) throws(Error) {
        let output: Process.Output
        let started = ContinuousClock.now
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: launcherPrefix + arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    directory: directory.path,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }

        if Self.expired(output.status, since: started, timeout: timeout) {
            let stderr = output.stderr ?? []
            throw Self.waiting(onLockIn: stderr)
                ? .locked(directory: directory.path.string)
                : .timedOut(directory: directory.path.string)
        }

        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
    }

    internal static func waiting(onLockIn stderr: [UInt8]) -> Swift.Bool {
        let needle = Array("is already running using".utf8)
        guard stderr.count >= needle.count else { return false }
        return (0...(stderr.count - needle.count)).contains { start in
            needle.indices.allSatisfy { offset in stderr[start + offset] == needle[offset] }
        }
    }
}

extension Package.Manager {

    public func evaluation(
        at directory: File.Directory,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Manifest.Evaluation {
        let json = try dump(at: directory, timeout: timeout, scratch: scratch)
        do throws(DecodingError) {
            return try json.decode(Package.Manifest.Evaluation.self)
        } catch {
            throw .manifest
        }
    }
}

extension Package.Manager {

    public func manifest(
        at directory: File.Directory,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Manifest {
        let json = try dump(at: directory, timeout: timeout, scratch: scratch)
        do throws(JSON.Error) {
            return try decode(json)
        } catch {
            throw .manifest
        }
    }

    private func decode(_ json: JSON) throws(JSON.Error) -> Package.Manifest {
        guard json.isObject else {
            throw .typeMismatch(expected: "Manifest object", got: "non-object JSON value")
        }
        let nameValue = json["name"]
        guard nameValue.isString else { throw .missingKey("name") }

        let versionValue = json["toolsVersion"]["_version"]
        guard versionValue.isString else { throw .missingKey("toolsVersion._version") }
        let version = try tools(Swift.String(versionValue))

        guard let values = json["dependencies"].array else {
            throw .missingKey("dependencies")
        }
        var dependencies: [Package.Dependency] = []
        dependencies.reserveCapacity(values.count)
        for value in values {
            dependencies.append(try dependency(value))
        }

        return Package.Manifest(
            name: Package.Name(_unchecked: Swift.String(nameValue)),
            toolsVersion: version,
            dependencies: dependencies
        )
    }

    private func dependency(_ json: JSON) throws(JSON.Error) -> Package.Dependency {
        guard json.isObject else {
            throw .typeMismatch(expected: "dependency object", got: "non-object JSON value")
        }

        if let record = json["fileSystem"].array?.first {
            let identity = try string(record["identity"], key: "fileSystem.identity")
            let path = try string(record["path"], key: "fileSystem.path")
            return .init(
                source: .path(path),
                name: Package.Name(_unchecked: identity),
                products: []
            )
        }

        if let record = json["sourceControl"].array?.first {
            let identity = try string(record["identity"], key: "sourceControl.identity")
            let remotes = record["location"]["remote"].array ?? []
            let value: Swift.String
            if let remote = remotes.first {
                value = try string(
                    remote["urlString"],
                    key: "sourceControl.location.remote.urlString"
                )
            } else {
                value = ""
            }
            let uri: URI
            do throws(URIError) {
                uri = try URI(value)
            } catch {
                throw .typeMismatch(expected: "valid URI per RFC 3986", got: value)
            }
            return .init(
                source: .url(uri, try requirement(record["requirement"])),
                name: Package.Name(_unchecked: identity),
                products: []
            )
        }

        if let record = json["registry"].array?.first {
            let value = try string(record["identity"], key: "registry.identity")
            return .init(
                source: .registry(try identity(value), try requirement(record["requirement"])),
                name: Package.Name(_unchecked: value),
                products: []
            )
        }

        throw .typeMismatch(
            expected: "fileSystem|sourceControl|registry dependency",
            got: "object without a dependency discriminator"
        )
    }

    private func requirement(_ json: JSON) throws(JSON.Error) -> Package.Requirement {
        guard json.isObject else {
            throw .typeMismatch(expected: "requirement object", got: "non-object JSON value")
        }
        if let value = json["exact"].array?.first {
            return .exact(try semantic(try string(value, key: "exact[0]")))
        }
        if let value = json["range"].array?.first {
            let lower = try semantic(try string(value["lowerBound"], key: "range.lowerBound"))
            let upper = try semantic(try string(value["upperBound"], key: "range.upperBound"))
            return lower..<upper
        }
        if let value = json["branch"].array?.first {
            return .branch(try string(value, key: "branch[0]"))
        }
        if let value = json["revision"].array?.first {
            return .revision(try string(value, key: "revision[0]"))
        }
        throw .typeMismatch(
            expected: "exact|range|branch|revision requirement",
            got: "object without a requirement discriminator"
        )
    }

    private func string(_ json: JSON, key: Swift.String) throws(JSON.Error) -> Swift.String {
        guard json.isString else { throw .missingKey(key) }
        return Swift.String(json)
    }

    private func tools(_ value: Swift.String) throws(JSON.Error) -> Version.Tools {
        var input = [Byte](utf8: value)[...]
        let parsed: Version.Tools?
        do throws(Version.Tools.ParserError) {
            parsed = try Version.Tools.parser.parse(&input)
        } catch {
            parsed = nil
        }
        guard let parsed, input.isEmpty else {
            throw .typeMismatch(expected: "valid swift-tools-version", got: value)
        }
        return parsed
    }

    private func semantic(_ value: Swift.String) throws(JSON.Error) -> Version.Semantic {
        var input = [Byte](utf8: value)[...]
        let parsed: Version.Semantic?
        do throws(Version.Semantic.ParserError) {
            parsed = try Version.Semantic.parser.parse(&input)
        } catch {
            parsed = nil
        }
        guard let parsed, input.isEmpty else {
            throw .typeMismatch(expected: "valid semantic version", got: value)
        }
        return parsed
    }

    private func identity(_ value: Swift.String) throws(JSON.Error) -> Package.Identity {
        guard let dot = value.firstIndex(of: ".") else {
            throw .typeMismatch(expected: "registry identity 'scope.name'", got: value)
        }
        return .init(
            scope: Swift.String(value[..<dot]),
            name: Swift.String(value[value.index(after: dot)...])
        )
    }
}

extension Package.Manager {

    public func resolution(
        at directory: File.Directory,
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Resolution {
        let location = (try Package.Manager.scratch(scratch, in: directory) / File.Path.Component(unchecked: "workspace-state.json")).path

        let bytes: [Byte]

        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try File(location).read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)

                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
        } catch {
            throw .state
        }

        let json: JSON
        do throws(JSON.Error) {
            json = try JSON.parse(Swift.String(decoding: bytes, as: UTF8.self))
        } catch {
            throw .state
        }

        do throws(DecodingError) {
            return try json.decode(Package.Resolution.self)
        } catch {
            throw .state
        }
    }
}

extension Package.Manager {
    internal func toolchain(
        timeout: Swift.Duration
    ) throws(Error) -> [Byte] {
        let output: Process.Output
        let started = ContinuousClock.now
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: launcherPrefix + ["--version"],
                    stdout: .pipe,
                    stderr: .pipe,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }
        if Self.expired(output.status, since: started, timeout: timeout) {
            throw .timedOut(directory: executable)
        }
        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
        guard let stdout = output.stdout, !stdout.isEmpty else {
            throw .toolchain
        }
        return stdout.map(Byte.init(bitPattern:))
    }
}
