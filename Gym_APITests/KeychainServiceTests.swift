import XCTest
@testable import Gym_API

final class KeychainServiceTests: XCTestCase {
    func testSaveGetAndDeleteToken() {
        let service = KeychainService.shared
        let token = "test-token-123"
        XCTAssertTrue(service.saveToken(token, type: .accessToken))
        XCTAssertEqual(service.getToken(type: .accessToken), token)
        XCTAssertTrue(service.deleteToken(type: .accessToken))
        XCTAssertNil(service.getToken(type: .accessToken))
    }
}

