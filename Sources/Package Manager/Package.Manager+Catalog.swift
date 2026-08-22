internal import FIPS_180_4
internal import File_System

extension Package.Manager {
    public func catalog(
        at directory: Swift.String,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Catalog {
        let before = try manifestSource(at: directory)
        let toolchain = try toolchain(timeout: timeout)
        let evaluation = try evaluation(
            at: directory,
            timeout: timeout,
            scratch: scratch
        )
        let after = try manifestSource(at: directory)
        guard before == after else {
            throw .manifestChanged(directory: directory)
        }
        return .init(
            manifest: FIPS_180_4.SHA256.digest(before).hex,
            toolchain: FIPS_180_4.SHA256.digest(toolchain).hex,
            evaluation: evaluation
        )
    }

    private func manifestSource(
        at directory: Swift.String
    ) throws(Error) -> [Byte] {
        let root: File.Directory
        do throws(File.Path.Error) {
            root = try File.Directory(validating: directory)
        } catch {
            throw .manifestUnavailable(directory: directory)
        }
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try root[file: "Package.swift"].read.full { bytes in
                var source = [Byte]()
                source.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    source.append(bytes[index])
                }
                return source
            }
        } catch {
            throw .manifestUnavailable(directory: directory)
        }
    }
}
