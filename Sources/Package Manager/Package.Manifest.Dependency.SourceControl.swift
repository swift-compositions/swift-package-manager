extension Package.Manifest.Dependency {

    public struct SourceControl: Swift.Sendable, Swift.Hashable {
        public let url: Location
        public let branch: Swift.String?
        public let document: Swift.String

        public init(url: Location, branch: Swift.String?, document: Swift.String) {
            self.url = url
            self.branch = branch
            self.document = document
        }
    }
}
