public import SPM_Standard

extension Package.Manager {
    public struct Catalog: Sendable {
        public let manifest: Swift.String
        public let toolchain: Swift.String
        public let evaluation: Package.Manifest.Evaluation

        public init(
            manifest: Swift.String,
            toolchain: Swift.String,
            evaluation: Package.Manifest.Evaluation
        ) {
            self.manifest = manifest
            self.toolchain = toolchain
            self.evaluation = evaluation
        }
    }
}
