public import SPM_Standard

extension Package.Build {

    public enum Error: Swift.Error, Sendable, Equatable {

        case execution(arguments: [Swift.String])

        case timedOut(arguments: [Swift.String])

        case failed(
            arguments: [Swift.String],
            termination: Package.Manager.Termination,
            stdout: [UInt8],
            stderr: [UInt8]
        )

        case compile(
            module: Swift.String,
            termination: Package.Manager.Termination,
            stdout: [UInt8],
            stderr: [UInt8]
        )
    }
}
