import Byte
import File_System
import Msgpack_Org_Messagepack
import Package_Manager
import Testing

extension `Package.Manager Tests` {

    @Suite
    struct `Plan Test` {

        static func commands(in root: Swift.String) -> [[Swift.String]] {
            let intermediates = root + "/Value-t.build/Objects-normal/arm64"
            let products = root + "/Products/Debug"
            let compile = [
                "/toolchain/swiftc", "-parse-as-library", "-module-name", "Value",
                "@" + intermediates + "/Value.SwiftFileList",
                "-output-file-map", intermediates + "/Value-OutputFileMap.json",
                "-emit-module-path", intermediates + "/Value.swiftmodule",
                "-working-directory", "/work",
            ]
            return [
                ["builtin-SwiftDriver", "--"] + compile,
                ["builtin-SwiftDriver", "--"] + compile,
                [
                    "/toolchain/clang", "-r", "-filelist", intermediates + "/Value.LinkFileList",
                    "-o", products + "/Value.o",
                ],
                [
                    "/toolchain/swiftc", "-emit-executable",
                    "@" + root + "/tool-p.build/Objects-normal/arm64/tool.LinkFileList",
                    "-o", products + "/tool",
                ],
                ["/usr/bin/codesign", "--force", "--sign", "-", products + "/tool"],
                ["Ld", products + "/tool", "normal"],
            ]
        }

        @Test
        func `compile, merge, link and signing steps are recognised`() throws {
            let plan = Package.Build.Plan(
                commands: Self.commands(in: "/build"),
                directory: try File.Directory(validating: "/package")
            )

            let compile = plan.compiles["Value"]
            #expect(plan.compiles.count == 1)
            #expect(compile?.directory == (try File.Directory(validating: "/work")))
            #expect(compile?.arguments.first == "/toolchain/swiftc")
            #expect(Set(plan.links.keys) == ["/build/Products/Debug/Value.o", "/build/Products/Debug/tool"])
            #expect(plan.links["/build/Products/Debug/tool"]?.directory == (try File.Directory(validating: "/package")))
            #expect(plan.signatures["/build/Products/Debug/tool"]?.arguments.first == "/usr/bin/codesign")
        }

        @Test
        func `a changed path no source list holds refuses as unlisted`() throws {
            let fixture = try EvaluationFixture.make()
            defer { EvaluationFixture.remove(fixture.root) }
            let plan = try #require(Self.plan(in: fixture.root))

            let replay = try plan.replay(changed: [fixture.package + "/Package.swift"], product: "tool")

            #expect(replay == .refused(.unlisted(path: fixture.package + "/Package.swift")))
        }

        @Test
        func `a source list's paths with spaces are listed in the form Swift Build writes them`() throws {
            let fixture = try EvaluationFixture.make()
            defer { EvaluationFixture.remove(fixture.root) }
            let plan = try #require(Self.plan(in: fixture.root))

            let escaped = try plan.replay(changed: [fixture.root + "/Sources/Value Sources/One.swift"], product: "absent")
            let quoted = try plan.replay(changed: [fixture.root + "/Sources/Value Sources/Two.swift"], product: "absent")

            #expect(escaped == .refused(.unlinked(product: "absent")))
            #expect(quoted == .refused(.unlinked(product: "absent")))
        }

        @Test
        func `a task store in both of its encodings gives the plan its command lines give`() throws {
            let fixture = try EvaluationFixture.make()
            defer { EvaluationFixture.remove(fixture.root) }
            let out = fixture.package + "/.build/out"
            let commands = Self.commands(in: out).filter { $0.first != "Ld" }
            var store: [Byte] = []
            for command in commands {
                if command.first == "builtin-SwiftDriver" {
                    store += Msgpack.Value.array(command.map { .string($0) }).bytes
                } else if command.first == "/usr/bin/codesign" {
                    store += Msgpack.Value.array([.string("CodeSign"), .string(command.last ?? "")]).bytes
                    store += Msgpack.Value.string("").bytes
                    store.append(Byte(bitPattern: UInt8(0x90 + command.count)))
                    for argument in command {
                        store += [Byte(bitPattern: 0x92), Byte(bitPattern: 0xe0), Byte(bitPattern: 0x00)]
                        store += Msgpack.Value.binary(argument.utf8.map { Byte(bitPattern: $0) }).bytes
                    }
                } else {
                    let output = command.last ?? ""
                    store += Msgpack.Value.array([.string("Ld"), .string(output), .string("normal")]).bytes
                    store += Msgpack.Value.string("").bytes
                    let elements: [Msgpack.Value] = command.map { argument in
                        .array([.integer(0), .binary(argument.utf8.map { Byte(bitPattern: $0) })])
                    }
                    store += Msgpack.Value.array(elements).bytes
                }
            }
            let data = out + "/Intermediates.noindex/XCBuildData/plan.xcbuilddata"
            #expect(EvaluationFixture.directory(at: data))
            #expect(EvaluationFixture.write(store.map(\.bitPattern), to: data + "/task-store.msgpack"))
            let directory = try File.Directory(validating: fixture.package)

            let read = Package.Build.Plan(product: "tool", at: directory, configuration: .debug)

            #expect(read == Package.Build.Plan(commands: commands, directory: directory))
            #expect(read?.compiles.count == 1)
            #expect(read?.links.count == 2)
            #expect(read?.signatures.count == 1)
            #expect(Package.Build.Plan(product: "tool", at: directory, configuration: .release) == nil)
        }

        @Test
        func `of two task stores the plan is read from the one the build used last, whichever was written last`() throws {
            let fixture = try EvaluationFixture.make()
            defer { EvaluationFixture.remove(fixture.root) }
            let out = fixture.package + "/.build/out"
            let data = out + "/Intermediates.noindex/XCBuildData"
            let plain = Self.commands(in: out).filter { $0.first != "Ld" && $0.first != "/usr/bin/codesign" }
            let coloured = plain.map { $0.first == "builtin-SwiftDriver" ? $0 + ["-color-diagnostics"] : $0 }
            for (name, commands) in [("aaaa", coloured), ("bbbb", plain)] {
                var store: [Byte] = []
                for command in commands {
                    if command.first == "builtin-SwiftDriver" {
                        store += Msgpack.Value.array(command.map { .string($0) }).bytes
                    } else {
                        store += Msgpack.Value.array([.string("Ld"), .string(command.last ?? ""), .string("normal")]).bytes
                        store += Msgpack.Value.array(command.map { .array([.integer(0), .binary($0.utf8.map { Byte(bitPattern: $0) })]) }).bytes
                    }
                }
                #expect(EvaluationFixture.directory(at: data + "/" + name + ".xcbuilddata"))
                #expect(EvaluationFixture.write(store.map(\.bitPattern), to: data + "/" + name + ".xcbuilddata/task-store.msgpack"))
            }
            let directory = try File.Directory(validating: fixture.package)
            #expect(EvaluationFixture.write("bbbb\naaaa\n", to: data + "/prior-build-descriptions.txt"))
            #expect(Package.Build.Plan(product: "tool", at: directory) == Package.Build.Plan(commands: coloured, directory: directory))
            #expect(EvaluationFixture.write("bbbb\naaaa\nbbbb\n", to: data + "/prior-build-descriptions.txt"))
            #expect(Package.Build.Plan(product: "tool", at: directory) == Package.Build.Plan(commands: plain, directory: directory))
        }

        static func plan(in root: Swift.String) -> Package.Build.Plan? {
            let intermediates = root + "/Value-t.build/Objects-normal/arm64"
            let directory: File.Directory
            do throws(File.Path.Error) {
                directory = try File.Directory(validating: root)
            } catch {
                return nil
            }
            guard EvaluationFixture.directory(at: intermediates) else { return nil }
            let sources = root + "/Sources/Value Sources"
            #if os(Windows)
                let list = """
                    "\(sources)/One.swift"
                    "\(sources)/Two.swift"

                    """
            #else
                let list = """
                    \(sources.replacing(" ", with: "\\ "))/One.swift
                    "\(sources)/Two.swift"

                    """
            #endif
            #expect(EvaluationFixture.write(list, to: intermediates + "/Value.SwiftFileList"))
            return Package.Build.Plan(commands: commands(in: root), directory: directory)
        }
    }
}
