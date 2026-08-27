import Package_Manager
import Testing

extension Package.Manifest.Clause {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Package.Manifest.Clause.Test.Unit {
    private static let manifest = """
        // swift-tools-version: 6.4
        import PackageDescription

        let package = Package(
            name: "consumer",
            dependencies: [
                .package(url: "https://github.com/foo/swift-alpha.git", branch: "main"),
                .package(url: "https://github.com/foo/swift-beta.git", .upToNextMajor(from: "1.0.0")),
                .package(path: "../swift-gamma")
            ],
            targets: []
        )
        """

    @Test
    func `all finds every package clause in source order`() {
        let clauses = Package.Manifest.Clause.all(in: Self.manifest)
        #expect(clauses.count == 3)
        #expect(clauses[0].declaredURL == "https://github.com/foo/swift-alpha.git")
        #expect(clauses[1].declaredURL == "https://github.com/foo/swift-beta.git")
        #expect(clauses[2].declaredPath == "../swift-gamma")
    }

    @Test
    func `nested parentheses in a requirement do not close the clause early`() {
        let clauses = Package.Manifest.Clause.all(in: Self.manifest)
        #expect(clauses[1].text.hasSuffix("(from: \"1.0.0\"))"))
        #expect(clauses[1].declaredURL == "https://github.com/foo/swift-beta.git")
    }

    @Test
    func `whitespace between package and its arguments is accepted`() {
        let source =
            #"dependencies: [.package (url: "https://example.com/swift-alpha.git", branch: "main")]"#
        #expect(
            Package.Manifest.Clause.all(in: source).first?.declaredURL
                == "https://example.com/swift-alpha.git"
        )
    }

    @Test
    func `source control facts include branch and exclude comments`() {
        let source = """
            // .package(url: "https://github.com/swift-molecules/ignored.git", branch: "feature")
            .package(url: "https://github.com/swift-molecules/swift-alpha.git", branch: "main")
            """
        let facts = Package.Manifest.Dependency.SourceControl.all(
            in: source,
            document: "Package.swift"
        )
        #expect(
            facts == [
                .init(
                    url: "https://github.com/swift-molecules/swift-alpha.git",
                    branch: "main",
                    document: "Package.swift"
                )
            ]
        )
    }

    @Test
    func `url locates the clause by derived identity`() {
        let clause = Package.Manifest.Clause.url(identity: "swift-beta", in: Self.manifest)
        #expect(clause?.declaredURL == "https://github.com/foo/swift-beta.git")
    }

    @Test
    func `url returns nil when no dependency has that identity`() {
        #expect(Package.Manifest.Clause.url(identity: "swift-delta", in: Self.manifest) == nil)
    }

    @Test(arguments: [
        ("https://github.com/foo/swift-alpha.git", "swift-alpha"),
        ("https://github.com/foo/swift-alpha", "swift-alpha"),
        ("https://github.com/foo/swift-alpha.git/", "swift-alpha"),
        ("https://github.com/Foo/Swift-Alpha.git", "swift-alpha"),
    ])
    func `identity derivation strips git, slash, and case`(
        url: Swift.String,
        expected: Swift.String
    ) {
        #expect(Package.Manifest.Clause.identity(ofURL: url) == expected)
    }

    @Test
    func `compose then restore is byte-identical`() {
        let original = Self.manifest
        let clause = Package.Manifest.Clause.url(identity: "swift-alpha", in: original)!
        let planned = ".package(path: \"/abs/Packages/swift-alpha\")"

        let composed = clause.replacing(with: planned, in: original)
        #expect(composed.contains(planned))
        #expect(!composed.contains("https://github.com/foo/swift-alpha.git"))

        let composedClause = Package.Manifest.Clause.all(in: composed).first { $0.text == planned }!
        let restored = composedClause.replacing(with: clause.text, in: composed)
        #expect(restored == original)
    }
}

extension Package.Manifest.Clause.Test.`Edge Case` {
    @Test
    func `a parenthesis inside a quoted path does not truncate the clause`() {
        let source = "deps: [.package(path: \"/tmp/a(b)/swift-x\")]"
        let clause = Package.Manifest.Clause.all(in: source).first
        #expect(clause?.declaredPath == "/tmp/a(b)/swift-x")
        #expect(clause?.text == ".package(path: \"/tmp/a(b)/swift-x\")")
    }

    @Test
    func `unbalanced parentheses stop enumeration without trapping`() {
        let source = ".package(url: \"https://example.com/x.git\""
        #expect(Package.Manifest.Clause.all(in: source).isEmpty)
    }

    @Test
    func `a url clause reports no declared path and a path clause no declared url`() {
        let url = Package.Manifest.Clause.all(
            in: ".package(url: \"https://e.com/x.git\", branch: \"main\")"
        ).first
        #expect(url?.declaredPath == nil)
        let path = Package.Manifest.Clause.all(in: ".package(path: \"/x\")").first
        #expect(path?.declaredURL == nil)
    }
}
