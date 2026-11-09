import Package_Manager
import Testing

enum `Package.Manifest.Identity.Conflict Tests` {}

extension `Package.Manifest.Identity.Conflict Tests` {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension `Package.Manifest.Identity.Conflict Tests`.Test.Unit {
    @Test
    func `two manifest locations for one identity are fatal`() {
        let entries = [
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("https://github.com/swift-standards/swift-rfc-7578.git")!,
                document: "Package.swift",
                source: .manifest
            ),
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("https://github.com/swift-ietf/swift-rfc-7578.git")!,
                document: "Package@swift-6.3.swift",
                source: .manifest
            ),
        ]

        let finding = Package.Manifest.Identity.Conflict.findings(in: entries).first
        #expect(finding?.identity == "swift-rfc-7578")
        #expect(finding?.disposition == .fatal)
    }

    @Test
    func `a resolved pin disagreeing with a manifest is stale`() {
        let entries = [
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("https://github.com/swift-ietf/swift-rfc-7578.git")!,
                document: "Package.swift",
                source: .manifest
            ),
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("https://github.com/swift-standards/swift-rfc-7578.git")!,
                document: "Package.resolved",
                source: .pin
            ),
        ]

        #expect(
            Package.Manifest.Identity.Conflict.findings(in: entries).first?.disposition == .stalePin
        )
    }

    @Test
    func `resolved locations are extracted by the package manager owner`() {
        let resolved =
            #"{"pins":[{"identity":"swift-rfc-7578","location":"https://github.com/swift-standards/swift-rfc-7578.git","state":{"revision":"abc","version":"1.0.0"}}],"version":2}"#

        let entries = Package.Manifest.Identity.Conflict.entries(inResolved: resolved)

        #expect(entries.count == 1)
        #expect(entries.first?.identity == "swift-rfc-7578")
        #expect(entries.first?.source == .pin)
    }
}

extension `Package.Manifest.Identity.Conflict Tests`.Test.`Edge Case` {
    @Test
    func `equivalent URL spellings share one canonical location`() {
        let entries = [
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("https://GitHub.com/swift-ietf/swift-rfc-7578.git/")!,
                document: "Package.swift",
                source: .manifest
            ),
            Package.Manifest.Identity.Conflict.Entry(
                url: Package.Manifest.Dependency.Location("git@github.com:swift-ietf/swift-rfc-7578")!,
                document: "Package@swift-6.3.swift",
                source: .manifest
            ),
        ]

        #expect(Package.Manifest.Identity.Conflict.findings(in: entries).isEmpty)
    }

    @Test
    func `manifest extraction stays inside package calls`() {
        let source = """
            let unrelated = "https://github.com/elsewhere/swift-alpha.git"
            dependencies: [
                .package (url: "https://github.com/swift-molecules/swift-alpha.git", branch: "main")
            ]
            """

        let entries = Package.Manifest.Identity.Conflict.entries(
            in: source,
            document: "Package.swift"
        )
        #expect(entries.count == 1)
        #expect(entries.first?.identity == "swift-alpha")
    }

    @Test
    func `commented-out package clauses are not manifest entries`() {
        let source = """
            dependencies: [
                // .package(url: "https://github.com/swift-ietf/swift-alpha.git", branch: "main"),
                /* .package(url: "https://github.com/elsewhere/swift-alpha.git", branch: "main"), */
                .package(url: "https://github.com/swift-molecules/swift-alpha.git", branch: "main")
            ]
            """

        let entries = Package.Manifest.Identity.Conflict.entries(
            in: source,
            document: "Package.swift"
        )
        #expect(entries.count == 1)
        #expect(Package.Manifest.Identity.Conflict.findings(in: entries).isEmpty)
    }
}
