private import JSON

extension Package.Manifest.Identity.Conflict {

    public static func entries(
        inResolved source: Swift.String,
        document: Swift.String = "Package.resolved"
    ) -> [Entry] {
        let json: JSON
        do throws(JSON.Error) {
            json = try JSON.parse(source)
        } catch {
            return []
        }
        guard let pins = json["pins"].array else { return [] }
        return pins.compactMap { pin in
            Package.Manifest.Dependency.Location(Swift.String(pin["location"])).map {
                Entry(url: $0, document: document, source: .pin)
            }
        }
    }
}
