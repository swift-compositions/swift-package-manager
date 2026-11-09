extension Package.Manifest.Identity.Conflict {

    public enum Error: Swift.Error, Swift.Sendable, Swift.Equatable {

        /// The resolved file is not JSON, or has no `pins` array in either
        /// the version 1 (`object.pins`) or later (`pins`) layout.
        case resolved(document: Swift.String)
    }
}
