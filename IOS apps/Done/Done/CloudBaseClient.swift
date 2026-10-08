//
//  CloudBaseClient.swift
//  Done
//
//  Created by Huaijin233 on 3/12/26.
//

import Foundation
import UIKit

struct CloudBaseConfiguration {
    let envId: String

    var authBaseURL: URL {
        URL(string: "https://\(envId).api.tcloudbasegateway.com")!
    }
}

struct CloudBaseToken: Codable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let subject: String?
    let scope: String?

    var isExpired: Bool {
        expiresAt.timeIntervalSinceNow <= 60
    }
}

struct CloudBaseSession: Codable {
    let profile: CloudBaseProfile
    let token: CloudBaseToken
}

struct CloudBaseProfile: Codable {
    struct Provider: Codable, Identifiable {
        let id: String
        let providerUserId: String?
        let name: String?
        let picture: String?
        let url: String?

        enum CodingKeys: String, CodingKey {
            case id
            case providerUserId = "provider_user_id"
            case name
            case picture
            case url
        }
    }

    let sub: String?
    let name: String?
    let picture: String?
    let username: String?
    let email: String?
    let phoneNumber: String?
    let providers: [Provider]?
    let hasPassword: Bool?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case name
        case picture
        case username
        case email
        case phoneNumber = "phone_number"
        case providers
        case hasPassword = "has_password"
        case userId = "user_id"
    }
}

struct CloudBaseProviderTokenResponse: Decodable {
    let providerToken: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case providerToken = "provider_token"
        case expiresIn = "expires_in"
    }
}

struct CloudBaseAppleAuthorizationContext {
    let authorizationURL: URL
    let callbackURL: URL
    let state: String
}

struct CloudBaseVerificationResponse: Decodable {
    let verificationId: String
    let expiresIn: Int
    let isUser: Bool?

    enum CodingKeys: String, CodingKey {
        case verificationId = "verification_id"
        case expiresIn = "expires_in"
        case isUser = "is_user"
    }
}

struct CloudBaseVerifiedCodeResponse: Decodable {
    let verificationToken: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case verificationToken = "verification_token"
        case expiresIn = "expires_in"
    }
}

struct CloudBaseSudoResponse: Decodable {
    let sudoToken: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case sudoToken = "sudo_token"
        case expiresIn = "expires_in"
    }
}

enum CloudBaseVerificationTarget: String {
    case any = "ANY"
    case user = "USER"
}

enum CloudBaseError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case invalidURL
    case server(message: String, code: String?)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "CloudBase configuration is missing."
        case .invalidResponse:
            return "The server returned an unreadable response."
        case .invalidURL:
            return "The request URL is invalid."
        case .server(let message, _):
            return message
        }
    }
}

private struct EmptyResponse: Codable {}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        encodeValue = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

private struct OAuthTokenResponse: Decodable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let subject: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case subject = "sub"
        case scope
    }

    func materialize(at date: Date = .now) -> CloudBaseToken {
        CloudBaseToken(
            tokenType: tokenType,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: date.addingTimeInterval(TimeInterval(expiresIn)),
            subject: subject,
            scope: scope
        )
    }
}

private struct CloudBaseAPIErrorResponse: Decodable {
    let error: String?
    let errorCode: Int?
    let errorDescription: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorCode = "error_code"
        case errorDescription = "error_description"
        case message
    }
}

private struct SignInRequest: Encodable {
    let username: String
    let password: String
}

private struct SignUpRequest: Encodable {
    let email: String
    let username: String
    let verificationToken: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case email
        case username
        case verificationToken = "verification_token"
        case password
    }
}

private struct VerificationRequest: Encodable {
    let email: String
    let target: String
}

private struct VerifyCodeRequest: Encodable {
    let verificationId: String
    let verificationCode: String

    enum CodingKeys: String, CodingKey {
        case verificationId = "verification_id"
        case verificationCode = "verification_code"
    }
}

private struct RefreshTokenRequest: Encodable {
    let grantType = "refresh_token"
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }
}

private struct ProviderTokenRequest: Encodable {
    let providerId: String
    let providerCode: String
    let providerRedirectURI: String?

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerCode = "provider_code"
        case providerRedirectURI = "provider_redirect_uri"
    }
}

private struct ProviderURIResponse: Decodable {
    let uri: String
}

private struct SignInWithProviderRequest: Encodable {
    let providerToken: String
    let forceDisableSignUp: Bool
    let syncProfile: Bool

    enum CodingKeys: String, CodingKey {
        case providerToken = "provider_token"
        case forceDisableSignUp = "force_disable_sign_up"
        case syncProfile = "sync_profile"
    }
}

private struct UpdateUserBasicRequest: Encodable {
    let username: String
}

private struct SudoRequest: Encodable {
    let password: String?
    let verificationToken: String?

    enum CodingKeys: String, CodingKey {
        case password
        case verificationToken = "verification_token"
    }
}

private struct UpdatePasswordRequest: Encodable {
    let oldPassword: String?
    let newPassword: String
    let confirmPassword: String

    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
        case confirmPassword = "confirm_password"
    }
}

final class CloudBaseClient {
    let configuration: CloudBaseConfiguration
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(configuration: CloudBaseConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func signIn(username: String, password: String, deviceId: String) async throws -> CloudBaseToken {
        let response: OAuthTokenResponse = try await request(
            path: "/auth/v1/signin",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(SignInRequest(username: username, password: password))
        )
        return response.materialize()
    }

    func signInAnonymously(deviceId: String) async throws -> CloudBaseToken {
        let response: OAuthTokenResponse = try await request(
            path: "/auth/v1/signin/anonymously",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(EmptyResponse())
        )
        return response.materialize()
    }

    func sendVerification(email: String, target: CloudBaseVerificationTarget = .any) async throws -> CloudBaseVerificationResponse {
        try await request(
            path: "/auth/v1/verification",
            method: "POST",
            body: AnyEncodable(VerificationRequest(email: email, target: target.rawValue))
        )
    }

    func verifyCode(verificationId: String, code: String, deviceId: String) async throws -> CloudBaseVerifiedCodeResponse {
        try await request(
            path: "/auth/v1/verification/verify",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(VerifyCodeRequest(verificationId: verificationId, verificationCode: code))
        )
    }

    func signUp(email: String, username: String, password: String, verificationToken: String, deviceId: String) async throws -> CloudBaseToken {
        let response: OAuthTokenResponse = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(SignUpRequest(email: email, username: username, verificationToken: verificationToken, password: password))
        )
        return response.materialize()
    }

    func appleAuthorizationContext(state: String, deviceId: String) async throws -> CloudBaseAppleAuthorizationContext {
        let response: ProviderURIResponse = try await request(
            path: "/auth/v1/provider/uri",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "provider_id", value: "apple"),
                URLQueryItem(name: "state", value: state)
            ],
            headers: ["x-device-id": deviceId]
        )

        guard let rawAuthorizationURL = URL(string: response.uri),
              var components = URLComponents(url: rawAuthorizationURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let callbackValue = queryItems.first(where: { $0.name == "redirect_uri" })?.value,
              let callbackURL = URL(string: callbackValue) else {
            throw CloudBaseError.invalidResponse
        }

        components.queryItems = normalizedAppleAuthorizationItems(from: queryItems)

        guard let authorizationURL = components.url else {
            throw CloudBaseError.invalidURL
        }

        return CloudBaseAppleAuthorizationContext(
            authorizationURL: authorizationURL,
            callbackURL: callbackURL,
            state: state
        )
    }

    func signInWithApple(
        authorizationCode: String,
        callbackURL: URL,
        deviceId: String,
        forceDisableSignUp: Bool
    ) async throws -> CloudBaseToken {
        let provider = try await grantProviderToken(
            providerId: "apple",
            providerCode: authorizationCode,
            providerRedirectURI: callbackURL.absoluteString,
            deviceId: deviceId
        )
        let response: OAuthTokenResponse = try await request(
            path: "/auth/v1/signin/with/provider",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(
                SignInWithProviderRequest(
                    providerToken: provider.providerToken,
                    forceDisableSignUp: forceDisableSignUp,
                    syncProfile: true
                )
            )
        )
        return response.materialize()
    }

    func refreshToken(_ refreshToken: String, deviceId: String) async throws -> CloudBaseToken {
        let response: OAuthTokenResponse = try await request(
            path: "/auth/v1/token",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(RefreshTokenRequest(refreshToken: refreshToken))
        )
        return response.materialize()
    }

    func currentUser(accessToken: String, deviceId: String) async throws -> CloudBaseProfile {
        try await request(
            path: "/auth/v1/user/me",
            method: "GET",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "x-device-id": deviceId
            ]
        )
    }

    func updateUserBasicInfo(accessToken: String, username: String, deviceId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/auth/v1/user/basic/edit",
            method: "POST",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "x-device-id": deviceId
            ],
            body: AnyEncodable(UpdateUserBasicRequest(username: username))
        )
    }

    func getSudoToken(accessToken: String, deviceId: String, password: String? = nil, verificationToken: String? = nil) async throws -> CloudBaseSudoResponse {
        try await request(
            path: "/auth/v1/user/sudo",
            method: "POST",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "x-device-id": deviceId
            ],
            body: AnyEncodable(SudoRequest(password: password, verificationToken: verificationToken))
        )
    }

    func updatePassword(accessToken: String, sudoToken: String, newPassword: String, oldPassword: String? = nil, deviceId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/auth/v1/user/password",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "sudo_token", value: sudoToken)],
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "x-device-id": deviceId
            ],
            body: AnyEncodable(
                UpdatePasswordRequest(
                    oldPassword: oldPassword,
                    newPassword: newPassword,
                    confirmPassword: newPassword
                )
            )
        )
    }

    func signOut(accessToken: String, deviceId: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/auth/v1/user/signout",
            method: "POST",
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "x-device-id": deviceId
            ],
            body: AnyEncodable(EmptyResponse())
        )
    }

    private func grantProviderToken(
        providerId: String,
        providerCode: String,
        providerRedirectURI: String? = nil,
        deviceId: String
    ) async throws -> CloudBaseProviderTokenResponse {
        try await request(
            path: "/auth/v1/provider/token",
            method: "POST",
            headers: ["x-device-id": deviceId],
            body: AnyEncodable(
                ProviderTokenRequest(
                    providerId: providerId,
                    providerCode: providerCode,
                    providerRedirectURI: providerRedirectURI
                )
            )
        )
    }

    private func normalizedAppleAuthorizationItems(from items: [URLQueryItem]) -> [URLQueryItem] {
        var normalized = items.filter { item in
            item.name != "scope" && item.name != "response_mode"
        }
        normalized.append(URLQueryItem(name: "response_mode", value: "query"))
        return normalized
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: AnyEncodable? = nil
    ) async throws -> Response {
        guard let relativeURL = URL(string: path, relativeTo: configuration.authBaseURL) else {
            throw CloudBaseError.invalidURL
        }

        let resolvedURL: URL
        if queryItems.isEmpty {
            resolvedURL = relativeURL
        } else {
            guard var components = URLComponents(url: relativeURL, resolvingAgainstBaseURL: true) else {
                throw CloudBaseError.invalidURL
            }
            components.queryItems = (components.queryItems ?? []) + queryItems
            guard let url = components.url else {
                throw CloudBaseError.invalidURL
            }
            resolvedURL = url
        }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        } else if method != "GET" {
            request.httpBody = Data("{}".utf8)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudBaseError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            if data.isEmpty, Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw CloudBaseError.invalidResponse
            }
        }

        if let apiError = try? decoder.decode(CloudBaseAPIErrorResponse.self, from: data) {
            let message = apiError.errorDescription ?? apiError.message ?? "Request failed."
            throw CloudBaseError.server(message: message, code: apiError.error)
        }

        throw CloudBaseError.invalidResponse
    }
}

func loadCloudBaseConfiguration() -> CloudBaseConfiguration? {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
          let config = NSDictionary(contentsOfFile: path),
          let envId = config["CLOUDBASE_ENV_ID"] as? String else {
        return nil
    }

    return CloudBaseConfiguration(envId: envId)
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if loadCloudBaseConfiguration() != nil {
            print("CloudBase configuration loaded")
        } else {
            print("CloudBase configuration missing")
        }
        return true
    }
}
