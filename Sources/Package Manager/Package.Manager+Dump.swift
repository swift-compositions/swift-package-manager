internal import JSON
internal import Process
internal import SPM_Standard

extension Package.Manager {

    internal func dump(
        at directory: Swift.String,
        timeout: Swift.Duration,
        scratch: Swift.String?
    ) throws(Error) -> JSON {
        var arguments = launcherPrefix + ["package"]
        if let scratch {
            arguments.append(contentsOf: ["--scratch-path", scratch])
        }
        arguments.append("dump-package")
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: executable,
                    arguments: arguments,
                    stdout: .pipe,
                    stderr: .pipe,
                    workingDirectory: directory,
                    timeout: timeout
                )
            )
        } catch {
            throw .execution
        }

        if case .signaled = output.status {
            throw .timedOut(directory: directory)
        }
        guard output.status == .exited(code: 0) else {
            throw .command(
                termination: termination(output.status),
                stderr: output.stderr ?? []
            )
        }
        guard let bytes = output.stdout else {
            throw .output
        }

        do throws(JSON.Error) {
            return try JSON.parse(Swift.String(decoding: bytes, as: UTF8.self))
        } catch {
            throw .manifest
        }
    }

    internal func termination(_ status: Process.Status) -> Termination {
        switch status {
        case .exited(let code): .exited(code: code)
        case .signaled(let signal): .signaled(signal: signal)
        case .stopped(let signal): .stopped(signal: signal)
        }
    }
}
