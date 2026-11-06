extension Package.Manifest.Dependency {

    /// Where a `.package(url:)` or a `Package.resolved` pin points, as written there.
    ///
    /// SwiftPM also takes scp-like git URLs (`git@host:org/repo`), which `RFC_3986.URI` and
    /// `WHATWG_URL.URL` refuse, and a local pin's path may hold spaces, so this holds the text and refuses only what
    /// no location can be: text that is empty or nothing but whitespace.
    public struct Location: Swift.Sendable, Swift.Hashable {

        public let text: Swift.String

        public init?(_ text: some Swift.StringProtocol) {
            guard !text.allSatisfy(\.isWhitespace) else { return nil }
            self.text = Swift.String(text)
        }
    }
}
