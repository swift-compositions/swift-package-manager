public import Path
public import SPM_Standard

extension Package.Manifest {

    public enum Redirection {}
}

extension Package.Manifest.Redirection {

    public static func redirect(
        _ source: Swift.String,
        // swift-linter:disable:next raw concept
        // REASON: a .package(url:) or pin location, as written in a manifest or Package.resolved: SSH and scp-like git URLs (git@host:org/repo) are legal there and RFC_3986.URI and WHATWG_URL.URL refuse them; it stays text.
        dependency url: Swift.String,
        to path: Path::Path
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

    public static func clause(path: Path::Path) -> Swift.String {
        let literal = path.string.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"")
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
