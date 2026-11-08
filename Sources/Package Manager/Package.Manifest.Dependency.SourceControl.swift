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

extension Package.Manifest.Dependency.SourceControl {

    public static func all(
        in source: Swift.String,
        document: Swift.String
    ) -> [Self] {
        Package.Manifest.Clause.all(in: Package.Manifest.Source.code(in: source)).compactMap {
            clause in
            clause.declaredURL.map {
                Self(url: $0, branch: clause.declaredBranch, document: document)
            }
        }
    }
}
