internal import Process

extension Package.Manager {

    public func edit(
        _ identity: Swift.String,
        path: Swift.String,
        at directory: Swift.String,
        timeout: Swift.Duration = .seconds(120)
    ) throws(Error) {
        try run(["package", "edit", identity, "--path", path], at: directory, timeout: timeout)
    }

    public func unedit(
        _ identity: Swift.String,
        at directory: Swift.String,
        force: Swift.Bool = false,
        timeout: Swift.Duration = .seconds(120)
    ) throws(Error) {
        try run(
            force
                ? ["package", "unedit", "--force", identity]
                : ["package", "unedit", identity],
            at: directory,
            timeout: timeout
        )
    }
}

extension Package.Manager {

    private func run(
        _ arguments: [Swift.String],
        at directory: Swift.String,
        timeout: Swift.Duration
    ) throws(Error) {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: launcherPrefix + arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    directory: directory,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }

        if case .signaled = output.status {
            let stderr = output.stderr ?? []
            throw Self.waiting(onLockIn: stderr)
                ? .locked(directory: directory)
                : .timedOut(directory: directory)
        }

        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
    }

    internal static func waiting(onLockIn stderr: [UInt8]) -> Swift.Bool {
        let needle = Array("is already running using".utf8)
        guard stderr.count >= needle.count else { return false }
        return (0...(stderr.count - needle.count)).contains { start in
            needle.indices.allSatisfy { offset in stderr[start + offset] == needle[offset] }
        }
    }
}
