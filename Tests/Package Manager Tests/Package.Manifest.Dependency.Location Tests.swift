import Package_Manager
import Testing

extension Package.Manifest.Dependency.Location {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Package.Manifest.Dependency.Location.Test.Unit {
    @Test(arguments: [
        "https://github.com/foo/swift-alpha.git",
        "git@github.com:foo/swift-alpha",
        "ssh://git@github.com/foo/swift-alpha.git",
        "/checkouts/swift-alpha",
        "/Users/someone/My Checkouts/swift-alpha",
    ])
    func `a location keeps its text as written`(text: Swift.String) {
        #expect(Package.Manifest.Dependency.Location(text)?.text == text)
    }
}

extension Package.Manifest.Dependency.Location.Test.`Edge Case` {
    @Test(arguments: ["", " ", "\n", " \t "])
    func `empty text and text of only whitespace are refused`(text: Swift.String) {
        #expect(Package.Manifest.Dependency.Location(text) == nil)
    }
}
