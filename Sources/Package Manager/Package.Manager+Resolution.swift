public import File_System
private import JSON
public import SPM_Standard

extension Package.Manager {

    public func resolution(
        at directory: File.Directory,
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Resolution {
        let location = (try Package.Manager.scratch(scratch, in: directory) / File.Path.Component(unchecked: "workspace-state.json")).path

        let bytes: [Byte]

        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try File(location).read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)

                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
        } catch {
            throw .state
        }

        let json: JSON
        do throws(JSON.Error) {
            json = try JSON.parse(Swift.String(decoding: bytes, as: UTF8.self))
        } catch {
            throw .state
        }

        do throws(DecodingError) {
            return try json.decode(Package.Resolution.self)
        } catch {
            throw .state
        }
    }
}
