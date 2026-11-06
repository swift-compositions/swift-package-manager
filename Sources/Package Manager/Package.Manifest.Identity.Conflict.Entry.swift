extension Package.Manifest.Identity.Conflict {

    public struct Entry: Swift.Sendable, Swift.Hashable {
        public let identity: Swift.String
        public let location: Swift.String
        public let document: Swift.String
        public let source: Source

        public init(url: Package.Manifest.Dependency.Location, document: Swift.String, source: Source) {
            self.identity = Package.Manifest.Clause.identity(ofURL: url)
            self.location = Package.Manifest.Identity.Conflict.canonical(url)
            self.document = document
            self.source = source
        }
    }
}
