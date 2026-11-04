import Package_Manager
import Testing

@Test
func `manifest invokes SwiftPM and decodes the standard model`() throws {
    let manifest = try Package.Manager().manifest(at: absolute(fixture: "Fixture"))
    #expect(manifest.name == "fixture")
    #expect(manifest.dependencies.isEmpty)
}
