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
