import Package_Manager
import Testing

extension Package.Manager {

    @Suite
    struct `Materialization Test` {

        private static func reference(
            _ identity: Swift.String,
            kind: Package.Resolution.Reference.Kind,
            location: Swift.String
        ) -> Package.Resolution.Reference {
            .init(identity: .init(identity), kind: kind, location: location, name: identity)
        }

        @Test
        func `a managed checkout compiles from the scratch directory, not its location`() {

            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-paths",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-paths"
                ),
                state: .sourceControlCheckout(.init(revision: "9bbec44", pin: .branch("main"))),
                subpath: "swift-paths"
            )

            let path = Package.Manager().materialized
                .source(of: dependency, at: "/fixture/root")

            #expect(path == "/fixture/root/.build/checkouts/swift-paths")

            #expect(path != dependency.reference.location)
        }

        @Test
        func `an explicit scratch directory overrides the default`() {
            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-paths",
                    kind: .localSourceControl,
                    location: "/fixture/worktrees/swift-paths"
                ),
                state: .sourceControlCheckout(.init(revision: "9bbec44", pin: .branch("main"))),
                subpath: "swift-paths"
            )

            let path = Package.Manager().materialized.source(
                of: dependency,
                at: "/fixture/root",
                scratch: "/fixture/scratch"
            )

            #expect(path == "/fixture/scratch/checkouts/swift-paths")
        }

        @Test
        func `a filesystem dependency compiles from its recorded path`() {

            let dependency = Package.Resolution.Dependency(
                reference: Self.reference(
                    "swift-css",
                    kind: .fileSystem,
                    location: "/fixture/packages/swift-css"
                ),
                state: .fileSystem(path: "/fixture/packages/swift-css"),
                subpath: "swift-css"
            )

            let path = Package.Manager().materialized
                .source(of: dependency, at: "/fixture/root", scratch: "/fixture/scratch")

            #expect(path == "/fixture/packages/swift-css")
            #expect(path.contains("checkouts") == false)
        }

        @Test
        func `an edited dependency compiles from its working copy`() {

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
                    path: "/fixture/edited/swift-parser",
                    basedOn: superseded
                ),
                subpath: "swift-parser"
            )

            let path = Package.Manager().materialized
                .source(of: dependency, at: "/fixture/root")

            #expect(path == "/fixture/edited/swift-parser")
            #expect(path.contains("checkouts") == false)

            #expect(dependency.state.superseded?.checkout.revision == "aaa111")
            #expect(dependency.revision == nil)
        }
    }
}
