public import File_System
internal import Process
public import SPM_Standard

extension Package.Build {

    public struct Step: Sendable, Equatable {

        public let directory: File.Directory

        public let arguments: [Swift.String]

        public init(directory: File.Directory, arguments: [Swift.String]) {
            self.directory = directory
            self.arguments = arguments
        }
    }
}

extension Package.Build.Step {

    public func run(timeout: Swift.Duration = .seconds(600)) throws(Package.Build.Error) {
        guard let executable = arguments.first else {
            throw .execution(arguments: arguments)
        }
        let output: Process.Output
        let started = ContinuousClock.now
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: Swift.Array(arguments.dropFirst()),
                    stdout: .pipe,
                    stderr: .pipe,
                    directory: directory.path,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution(arguments: arguments)
        }
        if Package.Manager.expired(output.status, since: started, timeout: timeout) {
            throw .timedOut(arguments: arguments)
        }
        guard output.status == .exited(code: 0) else {
            throw .failed(
                arguments: arguments,
                termination: Package.Manager.termination(output.status),
                stdout: output.stdout ?? [],
                stderr: output.stderr ?? []
            )
        }
    }
}

extension Package.Build.Step {

    internal func value(after option: Swift.String) -> Swift.String? {
        guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    internal func list(_ suffix: Swift.String) -> Swift.String? {
        arguments.first { $0.hasPrefix("@") && $0.hasSuffix(suffix) }.map { Swift.String($0.dropFirst()) }
    }

    internal var output: Swift.String? { value(after: "-o") }

    internal var links: Swift.String? { value(after: "-filelist") ?? list(".LinkFileList") }
}
