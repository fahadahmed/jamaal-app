import Testing
@testable import JamaalCore

@Test func reportsAVersion() {
    #expect(!JamaalCore.version.isEmpty)
}
