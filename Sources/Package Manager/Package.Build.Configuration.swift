public import SPM_Standard

extension Package.Build {

    public enum Configuration: Sendable, Equatable, Hashable {

        case debug

        case release
    }
}

extension Package.Build.Configuration {

    internal var name: Swift.String {
        switch self {
        case .debug: "debug"
        case .release: "release"
        }
    }

    internal var directory: Swift.String {
        switch self {
        case .debug: "Debug"
        case .release: "Release"
        }
    }
}
