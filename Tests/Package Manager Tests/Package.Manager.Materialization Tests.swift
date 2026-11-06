import File_System
import Package_Manager
import Path
import Testing

extension `Package.Manager Tests` {

    @Suite
    struct `Materialization Test` {

        /// A path's text with `/` separators, so one expectation holds on every platform.
        private static func text(_ path: File.Path) -> Swift.String {
            Swift.String(path.string.map { $0 == "\\" ? "/" : $0 })
        }

        private static func reference(
            _ identity: Swift.String,
            kind: Package.Resolution.Reference.Kind,
            location: Swift.String
        ) -> Package.Resolution.Reference {
            .init(identity: .init(identity), kind: kind, location: location, name: identity)
        }

        @Test
        func `a managed checkout compiles from the scratch directory, not its location`() throws {

            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-paths",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-paths"
                ),
                state: .sourceControlCheckout(.init(revision: "9bbec44", pin: .branch("main"))),
                subpath: "swift-paths"
            )

            let path = try Package.Manager().materialized
                .source(of: dependency, at: try File.Directory(validating: "/fixture/root"))

            #expect(Self.text(path) == "/fixture/root/.build/checkouts/swift-paths")

            #expect(path.string != dependency.reference.location)
        }

        @Test
        func `an explicit scratch directory overrides the default`() throws {
            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-paths",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-paths"
                ),
                state: .sourceControlCheckout(.init(revision: "9bbec44", pin: .branch("main"))),
                subpath: "swift-paths"
            )

            let path = try Package.Manager().materialized.source(
                of: dependency,
                at: try File.Directory(validating: "/fixture/root"),
                scratch: "/fixture/scratch"
            )

            #expect(Self.text(path) == "/fixture/scratch/checkouts/swift-paths")
        }

        @Test
        func `a filesystem dependency compiles from its recorded path`() throws {

            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-css",
                    kind: .fileSystem,
                    location: "/fixture/packages/swift-css"
                ),
                state: .fileSystem(path: try Path::Path(validating: "/fixture/packages/swift-css")),
                subpath: "swift-css"
            )

            let path = try Package.Manager().materialized
                .source(of: dependency, at: try File.Directory(validating: "/fixture/root"), scratch: "/fixture/scratch")

            #expect(Self.text(path) == "/fixture/packages/swift-css")
            #expect(path.string.contains("checkouts") == false)
        }

        @Test
        func `an edited dependency compiles from its working copy`() throws {

            let superseded = Package.Resolution.Dependency.Superseded(
                reference: Self.reference(
                    "swift-parser",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-parser"
                ),
                checkout: .init(revision: "aaa111", pin: .branch("main")),
                subpath: "swift-parser"
            )
            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-parser",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-parser"
                ),
                state: .edited(
                    path: try Path::Path(validating: "/fixture/edited/swift-parser"),
                    basedOn: superseded
                ),
                subpath: "swift-parser"
            )

            let path = try Package.Manager().materialized
                .source(of: dependency, at: try File.Directory(validating: "/fixture/root"))

            #expect(Self.text(path) == "/fixture/edited/swift-parser")
            #expect(path.string.contains("checkouts") == false)

            #expect(dependency.state.superseded?.checkout.revision == "aaa111")
            #expect(dependency.revision == nil)
        }
    }
}
