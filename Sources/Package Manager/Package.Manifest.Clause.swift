public import SPM_Standard

extension Package.Manifest {

    public struct Clause: Swift.Sendable, Swift.Equatable {

        public let text: Swift.String

        public let range: Swift.Range<Swift.Int>
    }
}

extension Package.Manifest.Clause {

    public static func all(in source: Swift.String) -> [Self] {
        let bytes = [Swift.UInt8](source.utf8)
        let marker = [Swift.UInt8](".package".utf8)

        var clauses: [Self] = []
        var index = 0
        while let start = firstIndex(of: marker, in: bytes, from: index) {
            var openParen = start + marker.count
            while openParen < bytes.count,
                bytes[openParen] == Swift.UInt8(ascii: " " as Swift.Unicode.Scalar)
                    || bytes[openParen] == Swift.UInt8(ascii: "\t" as Swift.Unicode.Scalar)
                    || bytes[openParen] == Swift.UInt8(ascii: "\n" as Swift.Unicode.Scalar)
                    || bytes[openParen] == Swift.UInt8(ascii: "\r" as Swift.Unicode.Scalar)
            {
                openParen += 1
            }
            guard openParen < bytes.count,
                bytes[openParen] == Swift.UInt8(ascii: "(" as Swift.Unicode.Scalar)
            else {
                index = start + marker.count
                continue
            }
            guard let close = closingParen(in: bytes, after: openParen + 1) else {

                break
            }
            let range = start..<(close + 1)
            clauses.append(
                .init(
                    text: Swift.String(decoding: bytes[range], as: Swift.UTF8.self),
                    range: range
                )
            )
            index = close + 1
        }
        return clauses
    }

    public static func url(
        identity: Swift.String,
        in source: Swift.String
    ) -> Self? {
        all(in: source).first { clause in
            guard let url = clause.declaredURL else { return false }
            return Self.identity(ofURL: url) == identity
        }
    }

    public var declaredURL: Swift.String? {
        Self.declaredURL(in: text)
    }

    public var declaredPath: Swift.String? {
        Self.declaredPath(in: text)
    }

    public var declaredBranch: Swift.String? {
        Self.quoted(after: "branch:", in: text)
    }

    public static func declaredURL(in text: Swift.String) -> Swift.String? {
        quoted(after: "url:", in: text)
    }

    public static func declaredPath(in text: Swift.String) -> Swift.String? {
        quoted(after: "path:", in: text)
    }

    public func replacing(
        with replacement: Swift.String,
        in source: Swift.String
    ) -> Swift.String {
        let bytes = [Swift.UInt8](source.utf8)
        var result = [Swift.UInt8]()
        result.reserveCapacity(bytes.count)
        result.append(contentsOf: bytes[bytes.startIndex..<range.lowerBound])
        result.append(contentsOf: replacement.utf8)
        result.append(contentsOf: bytes[range.upperBound..<bytes.endIndex])
        return Swift.String(decoding: result, as: Swift.UTF8.self)
    }

    // swift-linter:disable:next raw concept
    // REASON: a .package(url:) or pin location, as written in a manifest or Package.resolved: SSH and scp-like git URLs (git@host:org/repo) are legal there and RFC_3986.URI and WHATWG_URL.URL refuse them; it stays text.
    public static func identity(ofURL url: Swift.String) -> Swift.String {
        var value = url[...]
        while value.last == "/" { value = value.dropLast() }
        if value.hasSuffix(".git") { value = value.dropLast(4) }
        let component =
            value.split(separator: "/").last.map(Swift.String.init) ?? Swift.String(value)
        return component.lowercased()
    }
}

extension Package.Manifest.Clause {

    private static func quoted(after label: Swift.String, in text: Swift.String) -> Swift.String? {
        let bytes = [Swift.UInt8](text.utf8)
        let needle = [Swift.UInt8](label.utf8)
        let located = firstIndex(of: needle, in: bytes, from: 0)
        guard let labelStart = located else { return nil }

        let quote = Swift.UInt8(ascii: "\"" as Swift.Unicode.Scalar)
        var index = labelStart + needle.count
        while index < bytes.count, bytes[index] != quote { index += 1 }
        guard index < bytes.count else { return nil }
        let open = index + 1
        var close = open
        while close < bytes.count, bytes[close] != quote { close += 1 }
        guard close < bytes.count else { return nil }
        return Swift.String(decoding: bytes[open..<close], as: Swift.UTF8.self)
    }

    private static func closingParen(in bytes: [Swift.UInt8], after start: Swift.Int) -> Swift.Int? {
        let quote = Swift.UInt8(ascii: "\"" as Swift.Unicode.Scalar)
        let backslash = Swift.UInt8(ascii: "\\" as Swift.Unicode.Scalar)
        let open = Swift.UInt8(ascii: "(" as Swift.Unicode.Scalar)
        let close = Swift.UInt8(ascii: ")" as Swift.Unicode.Scalar)

        var depth = 1
        var index = start
        var insideString = false
        var escaped = false
        while index < bytes.count {
            let byte = bytes[index]
            if insideString {
                if escaped {
                    escaped = false
                } else if byte == backslash {
                    escaped = true
                } else if byte == quote {
                    insideString = false
                }
            } else {
                switch byte {
                case quote: insideString = true

                case open: depth += 1

                case close:
                    depth -= 1
                    if depth == 0 { return index }

                default: break
                }
            }
            index += 1
        }
        return nil
    }

    private static func firstIndex(
        of needle: [Swift.UInt8],
        in haystack: [Swift.UInt8],
        from: Swift.Int
    ) -> Swift.Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        var start = from
        let last = haystack.count - needle.count
        while start <= last {
            var offset = 0
            while offset < needle.count, haystack[start + offset] == needle[offset] {
                offset += 1
            }
            if offset == needle.count { return start }
            start += 1
        }
        return nil
    }
}
