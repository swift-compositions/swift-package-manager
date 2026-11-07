public import SPM_Standard

extension Package {

    public struct Manager: Sendable {
        public let executable: Swift.String

        public init(executable: Swift.String = Package.Manager.launcher) {
            self.executable = executable
        }
    }
}

extension Package.Manager {

    public static var launcher: Swift.String {
        #if os(Windows)
            "C:\\Windows\\System32\\cmd.exe"
        #else
            "/usr/bin/env"
        #endif
    }

    internal var launcherPrefix: [Swift.String] {
        guard executable == Package.Manager.launcher else { return [] }
        #if os(Windows)
            return ["/c", "swift"]
        #else
            return ["swift"]
        #endif
    }
}
