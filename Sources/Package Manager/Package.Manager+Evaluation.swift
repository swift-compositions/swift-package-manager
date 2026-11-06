public import File_System
private import JSON
public import SPM_Standard

extension Package.Manager {

    public func evaluation(
        at directory: File.Directory,
        timeout: Swift.Duration = .seconds(120),
        scratch: Swift.String? = nil
    ) throws(Error) -> Package.Manifest.Evaluation {
        let json = try dump(at: directory, timeout: timeout, scratch: scratch)
        do throws(DecodingError) {
            return try json.decode(Package.Manifest.Evaluation.self)
        } catch {
            throw .manifest
        }
    }
}
