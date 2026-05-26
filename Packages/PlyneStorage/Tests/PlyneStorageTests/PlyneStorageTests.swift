import Testing
@testable import PlyneStorage

@Test
func storageSchemaTracksCore() {
    #expect(PlyneStorage.supportedSchemaVersion > 0)
}
