public import SPM_Standard

extension Package.Build.Replay {

    public enum Refusal: Sendable, Equatable, Hashable {

        case unlisted(path: Swift.String)

        case interface(module: Swift.String)

        case unlinked(product: Swift.String)
    }
}
