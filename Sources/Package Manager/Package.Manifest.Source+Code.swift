extension Package.Manifest.Source {

    public static func code(in source: Swift.String) -> Swift.String {
        var bytes = [Swift.UInt8](source.utf8)
        let slash = Swift.UInt8(ascii: "/" as Swift.Unicode.Scalar)
        let star = Swift.UInt8(ascii: "*" as Swift.Unicode.Scalar)
        let quote = Swift.UInt8(ascii: "\"" as Swift.Unicode.Scalar)
        let backslash = Swift.UInt8(ascii: "\\" as Swift.Unicode.Scalar)
        let newline = Swift.UInt8(ascii: "\n" as Swift.Unicode.Scalar)
        let space = Swift.UInt8(ascii: " " as Swift.Unicode.Scalar)

        var index = 0
        var insideString = false
        var escaped = false
        var blockDepth = 0
        while index < bytes.count {
            if blockDepth > 0 {
                if index + 1 < bytes.count, bytes[index] == slash, bytes[index + 1] == star {
                    bytes[index] = space
                    bytes[index + 1] = space
                    blockDepth += 1
                    index += 2
                } else if index + 1 < bytes.count, bytes[index] == star,
                    bytes[index + 1] == slash
                {
                    bytes[index] = space
                    bytes[index + 1] = space
                    blockDepth -= 1
                    index += 2
                } else {
                    if bytes[index] != newline { bytes[index] = space }
                    index += 1
                }
            } else if insideString {
                if escaped {
                    escaped = false
                } else if bytes[index] == backslash {
                    escaped = true
                } else if bytes[index] == quote {
                    insideString = false
                }
                index += 1
            } else if bytes[index] == quote {
                insideString = true
                index += 1
            } else if index + 1 < bytes.count, bytes[index] == slash,
                bytes[index + 1] == slash
            {
                while index < bytes.count, bytes[index] != newline {
                    bytes[index] = space
                    index += 1
                }
            } else if index + 1 < bytes.count, bytes[index] == slash,
                bytes[index + 1] == star
            {
                bytes[index] = space
                bytes[index + 1] = space
                blockDepth = 1
                index += 2
            } else {
                index += 1
            }
        }
        return Swift.String(decoding: bytes, as: Swift.UTF8.self)
    }
}
