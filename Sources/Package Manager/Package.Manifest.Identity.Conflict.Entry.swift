extension Package.Manifest.Identity.Conflict {

    public struct Entry: Swift.Sendable, Swift.Hashable {
        public let identity: Swift.String
        public let location: Swift.String
        public let document: Swift.String
        public let source: Source

        // swift-linter:disable:next raw concept
        // REASON: a .package(url:) or pin location, as written in a manifest or Package.resolved: SSH and scp-like git URLs (git@host:org/repo) are legal there and RFC_3986.URI and WHATWG_URL.URL refuse them; it stays text.
        public init(url: Swift.String, document: Swift.String, source: Source) {
            self.identity = Package.Manifest.Clause.identity(ofURL: url)
            self.location = Package.Manifest.Identity.Conflict.canonical(url)
            self.document = document
            self.source = source
        }
    }
}
