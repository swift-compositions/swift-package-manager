public import SPM_Standard

extension Package.Build {

    public enum Replay: Sendable, Equatable {

        case rebuilt(modules: [Swift.String], product: Swift.String, duration: Swift.Duration)

        case refused(Refusal)
    }
}
