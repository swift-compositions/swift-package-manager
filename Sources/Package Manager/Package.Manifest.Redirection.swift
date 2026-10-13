public import SPM_Standard

extension Package.Manifest {

    public enum Redirection {}
}

extension Package.Manifest.Redirection {

    public static func redirect(
        _ source: Swift.String,
        dependency url: Swift.String,
        to path: Swift.String
    ) throws(Error) -> Rewrite {
        let identity = Package.Manifest.Clause.identity(ofURL: url)
        guard let clause = Package.Manifest.Clause.url(identity: identity, in: source) else {
            throw .dependencyNotDeclaredByURL(identity: identity)
        }
        let planned = Self.clause(path: path)
        return Rewrite(
            source: clause.replacing(with: planned, in: source),
            declared: clause.text,
            planned: planned
        )
    }

    public static func clause(path: Swift.String) -> Swift.String {
        let literal = path.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
        return ".package(path: \"\(literal)\")"
    }

    public static func restore(
        _ source: Swift.String,
        planned: Swift.String,
        declared: Swift.String
    ) throws(Error) -> Swift.String {
        let located = Package.Manifest.Clause.all(in: source).first { $0.text == planned }
        guard let clause = located else {
            throw .composedClauseAbsent(planned: planned)
        }
        return clause.replacing(with: declared, in: source)
    }
}
