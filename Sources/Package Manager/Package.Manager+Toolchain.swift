internal import File_System
internal import Process

extension Package.Manager {
    internal func toolchain(
        timeout: Swift.Duration
    ) throws(Error) -> [Byte] {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: launcherPrefix + ["--version"],
                    stdout: .pipe,
                    stderr: .pipe,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }
        if case .signaled = output.status {
            throw .timedOut(directory: executable)
        }
        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
        guard let stdout = output.stdout, !stdout.isEmpty else {
            throw .toolchain
        }
        return stdout.map(Byte.init)
    }
}
