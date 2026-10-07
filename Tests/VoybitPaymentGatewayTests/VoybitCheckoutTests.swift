import XCTest
@testable import VoybitPaymentGateway

final class VoybitCheckoutTests: XCTestCase {
    func testPublicID() throws {
        let id = "nYVvXxsYGr5LZk8Dn7hU0Q"
        XCTAssertEqual(try VoybitCheckout.publicID(from: "https://voybit.com/pay/\(id)"), id)
        XCTAssertThrowsError(try VoybitCheckout.publicID(from: "http://voybit.com/pay/\(id)"))
        XCTAssertThrowsError(try VoybitCheckout.publicID(from: "https://example.com/pay/\(id)"))
    }

    func testParseIgnoresNestedFields() throws {
        let id = "nYVvXxsYGr5LZk8Dn7hU0Q"
        let json = """
        {"deposit_instructions":{"status":"ready","address":"secret-address"},"status":"pending","public_id":"\(id)","checkout_url":"https://voybit.com/pay/\(id)"}
        """.data(using: .utf8)!
        let status = try VoybitCheckout.parse(json, publicID: id)
        XCTAssertEqual(status.status, "pending")
        XCTAssertFalse(status.confirmed)
        XCTAssertFalse(String(describing: status).contains("secret-address"))
    }

    func testStatusRequestHasNoAPIKey() async throws {
        let id = "nYVvXxsYGr5LZk8Dn7hU0Q"
        final class Mock: URLProtocol {
            static var request: URLRequest?
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {
                Mock.request = request
                let body = #"{"status":"paid","public_id":"nYVvXxsYGr5LZk8Dn7hU0Q","checkout_url":"https://voybit.com/pay/nYVvXxsYGr5LZk8Dn7hU0Q","deposit_instructions":{"address":"secret-address"}}"#.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
            }
            override func stopLoading() {}
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Mock.self]
        let session = URLSession(configuration: configuration)
        let status = try await VoybitCheckout(session: session, apiOrigin: "https://api.voybit.com").status(publicID: id)
        XCTAssertTrue(status.confirmed)
        XCTAssertNil(Mock.request?.value(forHTTPHeaderField: "X-Voybit-Api-Key"))
        XCTAssertEqual(Mock.request?.url?.absoluteString, "https://api.voybit.com/api/v1/checkout/\(id)")
    }
}
