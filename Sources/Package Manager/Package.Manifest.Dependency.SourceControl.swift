extension Package.Manifest.Dependency {

    public struct SourceControl: Swift.Sendable, Swift.Hashable {
        // swift-linter:disable:next raw concept
        // REASON: a .package(url:) or pin location, as written in a manifest or Package.resolved: SSH and scp-like git URLs (git@host:org/repo) are legal there and RFC_3986.URI and WHATWG_URL.URL refuse them; it stays text.
        public let url: Swift.String
        public let branch: Swift.String?
        public let document: Swift.String

        // swift-linter:disable:next raw concept
        // REASON: a .package(url:) or pin location, as written in a manifest or Package.resolved: SSH and scp-like git URLs (git@host:org/repo) are legal there and RFC_3986.URI and WHATWG_URL.URL refuse them; it stays text.
        public init(url: Swift.String, branch: Swift.String?, document: Swift.String) {
            self.url = url
            self.branch = branch
            self.document = document
        }
    }
}
