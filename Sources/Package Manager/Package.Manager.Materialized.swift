public import File_System
import Path
public import SPM_Standard

extension Package.Manager {

    public struct Materialized: Swift.Sendable {
    }
}

extension Package.Manager {

    public var materialized: Materialized { .init() }
}

extension Package.Manager.Materialized {

    public func source(
        of dependency: Package.Resolution.Dependency,
        at directory: File.Directory,
        scratch: Swift.String? = nil
    ) -> Swift.String {
        switch dependency.state {
        case .sourceControlCheckout:
            "\(scratch ?? "\(directory)/.build")/checkouts/\(dependency.subpath)"

        case .fileSystem(let path), .edited(let path, _):
            path.string
        }
    }
}
