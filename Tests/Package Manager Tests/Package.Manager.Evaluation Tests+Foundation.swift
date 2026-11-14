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

    /// Whether `text` was written to `path`.
    static func write(_ text: Swift.String, to path: Swift.String) -> Bool {
        FileManager.default.createFile(atPath: path, contents: Data(text.utf8))
    }

    /// Whether a directory was created at `path`, with its parents.
    static func directory(at path: Swift.String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// Whether `bytes` were written to `path`.
    static func write(_ bytes: [UInt8], to path: Swift.String) -> Bool {
        FileManager.default.createFile(atPath: path, contents: Data(bytes))
    }

    static func executable(at path: Swift.String, script: Swift.String) throws {
        try Data(script.utf8).write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }

    /// A copy of the Replay fixture in a new temporary directory, and where its executable is built.
    static func replay(file: Swift.String = #filePath) -> (root: Swift.String, package: Swift.String)? {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let package = root.appending(path: "replay")
        let fixture = URL(fileURLWithPath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Replay")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: fixture, to: package)
        } catch {
            return nil
        }
        return (root.path, package.path)
    }

    /// Whether `old` was found in the file at `path` and replaced with `new`.
    static func replace(_ old: Swift.String, with new: Swift.String, in path: Swift.String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path) else { return false }
        let text = Swift.String(decoding: data, as: UTF8.self)
        guard text.contains(old) else { return false }
        return FileManager.default.createFile(atPath: path, contents: Data(text.replacing(old, with: new).utf8))
    }

    /// What the executable at `path` prints on standard output, or nil when it cannot be started.
    static func output(of path: Swift.String) -> Swift.String? {
        let process = Foundation.Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Swift.String(decoding: data, as: UTF8.self)
    }
}
