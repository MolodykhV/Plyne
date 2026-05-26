import Testing
@testable import PlyneCore

@Test
func schemaVersionIsPositive() {
    #expect(PlyneCore.schemaVersion > 0)
}
