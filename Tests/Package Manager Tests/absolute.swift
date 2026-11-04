/// A fixture's absolute path, because a test runner's working directory need not be the package root.
func absolute(fixture name: Swift.String, file: Swift.String = #filePath) -> Swift.String {
    var path = Substring(file)
    for _ in 0..<2 {
        guard let separator = path.lastIndex(where: { $0 == "/" || $0 == "\\" }) else { break }
        path = path[..<separator]
    }
    return "\(path)/Fixtures/\(name)"
}
