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

    /// Where `dependency`'s sources are compiled from: a managed checkout under the scratch directory, which defaults to
    /// `.build` in `directory`, or a file-system dependency's recorded path. Joined by component, so the separators are
    /// the platform's own. Throws ``Package/Manager/Error/state`` when `scratch` is not a path.
    public func source(
        of dependency: Package.Resolution.Dependency,
        at directory: File.Directory,
        scratch: Swift.String? = nil
    ) throws(Package.Manager.Error) -> File.Path {
        switch dependency.state {
        case .sourceControlCheckout:
            let checkouts = try Package.Manager.scratch(scratch, in: directory) / File.Path.Component(unchecked: "checkouts")
            return (checkouts / File.Path.Component(unchecked: dependency.subpath)).path

        case .fileSystem(let path), .edited(let path, _):
            return path
        }
    }
}

extension Package.Manager {
    /// The scratch directory: `scratch` when given, `.build` in `directory` otherwise.
    static func scratch(_ scratch: Swift.String?, in directory: File.Directory) throws(Package.Manager.Error) -> File.Directory {
        guard let scratch else { return directory / File.Path.Component(unchecked: ".build") }
        do throws(File.Path.Error) {
            return File.Directory(try File.Path(scratch))
        } catch {
            throw .state
        }
    }
}
