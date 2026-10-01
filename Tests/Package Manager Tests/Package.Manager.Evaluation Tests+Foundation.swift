import Foundation

enum EvaluationFixture {

    static func make() throws -> (root: Swift.String, package: Swift.String, scratch: Swift.String) {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let package = root.appending(path: "fixture")
        let scratch = root.appending(path: "scratch")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(name: "fixture")
            """.utf8
        ).write(to: package.appending(path: "Package.swift"))
        return (root.path, package.path, scratch.path)
    }

    static func remove(_ path: Swift.String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    static func exists(_ path: Swift.String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func executable(at path: Swift.String, script: Swift.String) throws {
        try Data(script.utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
}
