import Foundation

public struct CheckoutException: Error, CustomStringConvertible, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

public struct CheckoutStatus: Equatable, Sendable {
    public let publicId: String
    public let status: String
    public let checkoutUrl: String
    public var confirmed: Bool { status == "paid" || status == "overpaid" }

    public init(publicId: String, status: String, checkoutUrl: String) {
        self.publicId = publicId
        self.status = status
        self.checkoutUrl = checkoutUrl
    }
}

public struct VoybitCheckout: Sendable {
    public static let checkoutOrigin = "https://voybit.com"
    public static let apiOrigin = "https://api.voybit.com"
    private static let publicID = #"^[A-Za-z0-9_-]{22}$"#

    public var session: URLSession
    public var apiOrigin: String

    public init(session: URLSession? = nil, apiOrigin: String = VoybitCheckout.apiOrigin) {
        self.apiOrigin = apiOrigin
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            self.session = URLSession(configuration: configuration, delegate: RedirectStopper(), delegateQueue: nil)
        }
    }

    public static func publicID(from checkoutURL: String) throws -> String {
        guard let components = URLComponents(string: checkoutURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "https",
              components.host?.lowercased() == "voybit.com",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let path = components.path as String?
        else {
            throw CheckoutException("checkout URL is invalid")
        }
        let id = path.hasSuffix("/") ? String(path.dropLast()) : path
        let publicID = id.replacingOccurrences(of: "/pay/", with: "")
        guard id == "/pay/\(publicID)", publicID.range(of: Self.publicID, options: .regularExpression) != nil else {
            throw CheckoutException("checkout URL is invalid")
        }
        return publicID
    }

    public static func checkoutURL(publicID: String) throws -> URL {
        guard publicID.range(of: Self.publicID, options: .regularExpression) != nil,
              let url = URL(string: "\(checkoutOrigin)/pay/\(publicID)")
        else {
            throw CheckoutException("checkout URL is invalid")
        }
        return url
    }

    public func status(publicID: String) async throws -> CheckoutStatus {
        let id = try Self.publicID(from: Self.checkoutURL(publicID: publicID).absoluteString)
        guard let url = URL(string: "\(apiOrigin)/api/v1/checkout/\(id)") else {
            throw CheckoutException("checkout URL is invalid")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("voybit-payment-gateway-swift/0.1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CheckoutException("checkout status returned HTTP 0")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CheckoutException("checkout status returned HTTP \(http.statusCode)")
        }
        guard data.count <= 1 << 20 else {
            throw CheckoutException("checkout status was too large")
        }
        return try Self.parse(data, publicID: id)
    }

    static func parse(_ data: Data, publicID: String) throws -> CheckoutStatus {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let status = object?["status"] as? String else {
            throw CheckoutException("checkout status was not JSON")
        }
        let id = object?["public_id"] as? String ?? publicID
        let checkout = object?["checkout_url"] as? String ?? checkoutOrigin + "/pay/" + id
        guard id.range(of: Self.publicID, options: .regularExpression) != nil else {
            throw CheckoutException("checkout status was not JSON")
        }
        return CheckoutStatus(publicId: id, status: status, checkoutUrl: checkout)
    }
}

private final class RedirectStopper: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
