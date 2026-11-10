import File_System
import Package_Manager
import Testing

private enum Machine {}

extension Machine {

    static func checkout() throws -> File.Directory {
        try File.Directory(validating: ".build/checkouts/swift-spm-standard")
    }

    static var substitutes: Bool {
        let directory: File.Directory
        do {
            directory = try checkout()
        } catch {
            return false
        }
        do throws(Package.Manager.Error) {
            let evaluation = try Package.Manager().evaluation(at: directory)
            return evaluation.dependencies.contains { dependency in
                guard case .sourceControl(_, .local, _) = dependency.source
                else { return false }
                return true
            }
        } catch {

            return false
        }
    }
}

enum `Package.Manager Tests` {}

extension `Package.Manager Tests` {

    @Suite
    struct Test {

        @Suite
        struct Unit {

            @Test
            func `evaluation returns the package name`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                #expect(evaluation.name == "composed")
            }

            @Test
            func `evaluation preserves the tools version`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                #expect(Swift.String(describing: evaluation.toolsVersion) == "6.3.0")
            }

            @Test
            func `evaluation reports the declared dependency`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                #expect(evaluation.dependencies.isEmpty == false)
                #expect(evaluation.dependencies.count == 1)
                #expect(evaluation.dependencies[0].identity == "dependency")
            }

            @Test
            func `a genuine path dependency stays a filesystem source`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                let dependency = try #require(evaluation.dependencies.first)
                guard case .fileSystem(let identity, let path) = dependency.source else {
                    Issue.record("Expected .fileSystem, got \(dependency.source)")
                    return
                }
                #expect(identity == "dependency")

                #expect(path.replacing("\\", with: "/").hasSuffix("Tests/Fixtures/Dependency"))
            }

            @Test
            func `no requirement is invented for a path dependency`() throws {

                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                let dependency = try #require(evaluation.dependencies.first)
                #expect(dependency.requirement == nil)
            }

            @Test
            func `products survive the evaluation`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                #expect(evaluation.products.count == 2)
                #expect(evaluation.products.map(\.name) == ["Composed", "Composed Helper"])
            }

            @Test
            func `targets survive the evaluation`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                #expect(evaluation.targets.count == 2)
                #expect(evaluation.targets.map(\.name) == ["Composed", "Composed Helper"])
            }

            @Test
            func `platforms survive the evaluation`() throws {
                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                let platforms = try #require(evaluation.platforms)
                #expect(platforms.count == 2)
                #expect(platforms.map(\.platform) == [.macOS, .iOS])
                #expect(platforms.map(\.version.description) == ["13.0", "16.0"])
            }

            @Test
            func `dependency products are back-filled from target edges`() throws {

                let evaluation = try Package.Manager()
                    .evaluation(at: absolute(fixture: "Composed"))
                let dependency = try #require(evaluation.dependencies.first)
                #expect(dependency.products == ["Dependency Core"])
            }

            @Test
            func `an unusable package directory fails as an operational error`() throws {
                #expect(throws: Package.Manager.Error.self) {
                    try Package.Manager()
                        .evaluation(at: absolute(fixture: "Does Not Exist"))
                }
            }

            @Test
            func `an unsuccessful termination preserves stderr`() throws {
                let broken = try absolute(fixture: "Broken")
                do throws(Package.Manager.Error) {
                    _ = try Package.Manager().evaluation(at: broken)
                    Issue.record("Expected the broken fixture to fail")
                } catch {
                    guard case .command(let termination, let stderr) = error else {
                        Issue.record("Expected .command, got \(error)")
                        return
                    }
                    #expect(termination != .exited(code: 0))
                    #expect(stderr.isEmpty == false)
                    let text = Swift.String(decoding: stderr, as: UTF8.self)
                    #expect(text.contains("Broken"))
                }
            }

            @Test
            func `manifest keeps its existing behaviour after the refactor`() throws {

                let manager = Package.Manager()

                let bare = try manager.manifest(at: absolute(fixture: "Fixture"))
                #expect(bare.name == "fixture")
                #expect(bare.dependencies.isEmpty)

                let composed = try manager.manifest(at: absolute(fixture: "Composed"))
                #expect(composed.name == "composed")
                #expect(composed.dependencies.count == 1)
            }

            @Test
            func `manifest and evaluation agree on what they both report`() throws {
                let manager = Package.Manager()
                let manifest = try manager.manifest(at: absolute(fixture: "Composed"))
                let evaluation = try manager.evaluation(at: absolute(fixture: "Composed"))
                #expect(manifest.name == evaluation.name)
                #expect(manifest.toolsVersion == evaluation.toolsVersion)
                #expect(manifest.dependencies.count == evaluation.dependencies.count)
            }

            @Test
            func `evaluation puts SwiftPM state in the supplied scratch directory`() throws {
                let fixture = try Self.fixture()
                defer { EvaluationFixture.remove(fixture.root) }

                let evaluation = try Package.Manager().evaluation(
                    at: try File.Directory(validating: fixture.package),
                    scratch: fixture.scratch
                )

                #expect(evaluation.name == "fixture")
                #expect(EvaluationFixture.exists(fixture.scratch))
                #expect(
                    EvaluationFixture.exists(fixture.package + "/.build") == false
                )
            }

            #if !os(Windows)
                @Test
                func `evaluation reports the package directory when its process exceeds the bound`()
                    throws
                {
                    let fixture = try Self.fixture()
                    defer { EvaluationFixture.remove(fixture.root) }
                    let executable = fixture.root + "/hang"
                    try EvaluationFixture.executable(at: executable, script: "#!/bin/sh\nsleep 5\n")

                    #expect(
                        throws: Package.Manager.Error.timedOut(directory: fixture.package)
                    ) {
                        _ = try Package.Manager(executable: executable).evaluation(
                            at: try File.Directory(validating: fixture.package),
                            timeout: .milliseconds(50),
                            scratch: fixture.scratch
                        )
                    }
                }

                @Test
                func `a signal sent before the bound is a command failure, not a timeout`() throws {
                    let fixture = try Self.fixture()
                    defer { EvaluationFixture.remove(fixture.root) }
                    let executable = fixture.root + "/terminate"
                    try EvaluationFixture.executable(
                        at: executable,
                        script: "#!/bin/sh\nkill -TERM $$\n"
                    )

                    #expect(
                        throws: Package.Manager.Error.command(
                            termination: .signaled(signal: 15),
                            stderr: []
                        )
                    ) {
                        _ = try Package.Manager(executable: executable).evaluation(
                            at: try File.Directory(validating: fixture.package),
                            timeout: .seconds(120),
                            scratch: fixture.scratch
                        )
                    }
                }
            #endif

            @Test
            func `catalog binds targets to exact manifest bytes and the active toolchain`() throws {
                let fixture = try Self.fixture()
                defer { EvaluationFixture.remove(fixture.root) }

                let catalog = try Package.Manager().catalog(
                    at: try File.Directory(validating: fixture.package),
                    scratch: fixture.scratch
                )

                #expect(catalog.manifest.count == 64)
                #expect(catalog.toolchain.count == 64)
                #expect(catalog.evaluation.name == "fixture")
            }

            @Test
            func `catalog digest covers version-specific manifests`() throws {
                let fixture = try Self.fixture()
                defer { EvaluationFixture.remove(fixture.root) }
                let directory = try File.Directory(validating: fixture.package)

                let bare = try Package.Manager().catalog(at: directory, scratch: fixture.scratch)
                #expect(
                    EvaluationFixture.write(
                        """
                        // swift-tools-version: 6.4
                        import PackageDescription

                        let package = Package(name: "fixture")
                        """,
                        to: fixture.package + "/Package@swift-6.4.swift"
                    )
                )
                let versioned = try Package.Manager().catalog(at: directory, scratch: fixture.scratch)

                #expect(bare.manifest != versioned.manifest)
            }

            #if !os(Windows)
                @Test
                func `catalog fails when the manifest changes during evaluation`() throws {
                    let fixture = try Self.fixture()
                    defer { EvaluationFixture.remove(fixture.root) }
                    let executable = fixture.root + "/touching"
                    try EvaluationFixture.executable(
                        at: executable,
                        script: """
                            #!/bin/sh
                            if [ "$1" = package ]; then echo "// changed" >> Package.swift; fi
                            exec swift "$@"

                            """
                    )

                    #expect(
                        throws: Package.Manager.Error.manifestChanged(directory: fixture.package)
                    ) {
                        _ = try Package.Manager(executable: executable).catalog(
                            at: try File.Directory(validating: fixture.package),
                            scratch: fixture.scratch
                        )
                    }
                }
            #endif
        }

        @Suite(
            .enabled(
                if: Machine.substitutes,
                """
                No dependency of the observed checkout is mirror-substituted to \
                a local path on this machine.
                """
            )
        )
        struct Integration {

            @Test
            func `a mirror-substituted dependency stays source control with a local location`()
                throws
            {
                let evaluation = try Package.Manager().evaluation(at: Machine.checkout())

                var observed = 0
                for dependency in evaluation.dependencies {
                    guard
                        case .sourceControl(let identity, let location, _) =
                            dependency.source
                    else { continue }
                    guard case .local(let path) = location else { continue }
                    observed += 1

                    if case .fileSystem = dependency.source {
                        Issue.record("Mirror-substituted source became .fileSystem")
                    }

                    #expect(dependency.requirement != nil)

                    #expect(path.isEmpty == false)
                    #expect(path.hasPrefix("/"))
                    #expect(path.hasPrefix("file://") == false)
                    #expect(Swift.String(describing: identity).isEmpty == false)
                }

                #expect(observed > 0)
            }
        }
    }
}

extension `Package.Manager Tests`.Test.Unit {
    private static func fixture() throws -> (root: Swift.String, package: Swift.String, scratch: Swift.String) {
        try EvaluationFixture.make()
    }
}
