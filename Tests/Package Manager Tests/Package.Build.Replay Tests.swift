#if os(macOS)
    import File_System
    import Package_Manager
    import Testing

    extension `Package.Manager Tests` {

        @Suite
        struct `Replay Test` {

            @Test
            func `a replay rebuilds a body change and refuses an interface change`() throws {
                let fixture = try #require(EvaluationFixture.replay())
                defer { EvaluationFixture.remove(fixture.root) }
                let executable = fixture.package + "/.build/out/Products/Debug/replay"
                let directory = try File.Directory(validating: fixture.package)
                let source = fixture.package + "/Sources/Replay Value/Value.swift"

                try Package.Manager().build(product: "replay", at: directory)
                #expect(EvaluationFixture.output(of: executable) == "42\n")

                let plan = try #require(Package.Build.Plan(product: "replay", at: directory))
                #expect(EvaluationFixture.replace("6 * 7", with: "6 * 8", in: source))
                let replay = try plan.replay(changed: [source], product: "replay")
                guard case .rebuilt(let modules, let product, _) = replay else {
                    Issue.record("Expected a rebuild, got \(replay)")
                    return
                }
                #expect(modules == ["Replay_Value"])
                #expect(product.hasSuffix("/replay/.build/out/Products/Debug/replay"))
                #expect(EvaluationFixture.output(of: executable) == "48\n")

                #expect(
                    EvaluationFixture.replace(
                        "    }\n}",
                        with: "    }\n\n    public static func added() -> Int { 1 }\n}",
                        in: source
                    )
                )
                #expect(
                    try plan.replay(changed: [source], product: "replay")
                        == .refused(.interface(module: "Replay_Value"))
                )

                #expect(EvaluationFixture.replace("6 * 8", with: "6 *", in: source))
                do throws(Package.Build.Error) {
                    _ = try plan.replay(changed: [source], product: "replay")
                    Issue.record("Expected the syntax error to fail the compile")
                } catch {
                    guard case .compile(let module, _, let stdout, let stderr) = error else {
                        Issue.record("Expected .compile, got \(error)")
                        return
                    }
                    #expect(module == "Replay_Value")
                    let output = Swift.String(decoding: stdout + stderr, as: UTF8.self)
                    #expect(output.contains("Value.swift:4:5: error: expected expression after operator"))
                }
            }
        }
    }
#endif
