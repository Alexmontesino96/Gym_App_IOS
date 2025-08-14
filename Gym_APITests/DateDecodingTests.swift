import XCTest
@testable import Gym_API

final class DateDecodingTests: XCTestCase {
    struct Model: Codable { let date: Date }

    func testServerDecoderParsesISO8601WithZ() throws {
        let json = "{\"date\":\"2025-08-12T18:30:00Z\"}".data(using: .utf8)!
        let decoder = DateDecoding.serverDecoder()
        let model = try decoder.decode(Model.self, from: json)
        XCTAssertNotNil(model.date)
    }

    func testServerDecoderParsesFractionalSeconds() throws {
        let json = "{\"date\":\"2025-08-12T18:30:00.123456Z\"}".data(using: .utf8)!
        let decoder = DateDecoding.serverDecoder()
        let model = try decoder.decode(Model.self, from: json)
        XCTAssertNotNil(model.date)
    }
}

