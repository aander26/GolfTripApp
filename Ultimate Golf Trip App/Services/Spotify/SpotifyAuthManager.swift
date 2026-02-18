import Foundation
import AuthenticationServices

// MARK: - Spotify OAuth Manager
// Handles the OAuth Authorization Code flow using ASWebAuthenticationSession.
//
// Flow:
// 1. User taps "Connect Spotify"
// 2. We open Spotify's /authorize page in a system browser sheet
// 3. User logs in + grants scopes
// 4. Spotify redirects to our callback URL with an authorization code
// 5. We send that code to our backend, which exchanges it for access + refresh tokens
// 6. Backend stores tokens — app only knows "connected" or "disconnected"

@Observable
class SpotifyAuthManager {

    // MARK: - Configuration
    // ASSUMPTION: These values come from your Spotify Developer Dashboard.
    // The client secret is NEVER stored in the app — it lives on the backend.

    /// Your Spotify app's Client ID — loaded from Info.plist (key: SpotifyClientID)
    private let clientId: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String, !id.isEmpty else {
            fatalError("SpotifyClientID not found in Info.plist. Add it under the key 'SpotifyClientID'.")
        }
        return id
    }()

    /// The redirect URI registered in your Spotify app settings.
    /// Must use a custom URL scheme that your app handles.
    private let redirectUri = "golftrip://spotify-callback"

    /// The custom URL scheme portion (used by ASWebAuthenticationSession)
    private let callbackScheme = "golftrip"

    /// Scopes required for collaborative playlist management
    private let scopes = [
        "playlist-modify-public",
        "playlist-modify-private",
        "playlist-read-private"
    ]

    // MARK: - State

    var authState: SpotifyAuthState = .disconnected
    var isAuthenticating = false
    var authError: String?

    var isConnected: Bool { authState.isConnected }

    // MARK: - OAuth Flow

    /// Kick off the Spotify OAuth login flow.
    /// Opens a system browser sheet for the user to authorize our app.
    @MainActor
    func startAuthFlow() async {
        isAuthenticating = true
        authError = nil

        // Build the Spotify authorization URL
        guard let authURL = buildAuthURL() else {
            authError = "Failed to build authorization URL."
            isAuthenticating = false
            return
        }

        do {
            // Present the ASWebAuthenticationSession
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: callbackScheme
                ) { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: SpotifyError.authFailed)
                    }
                }
                session.prefersEphemeralWebBrowserSession = false // Keep user logged in
                session.start()
            }

            // Extract the authorization code from the callback URL
            guard let code = extractAuthCode(from: callbackURL) else {
                authError = "No authorization code received."
                isAuthenticating = false
                return
            }

            // Exchange the code for tokens via our backend
            let state = try await SpotifyService.shared.exchangeAuthCode(code, redirectUri: redirectUri)
            authState = state

        } catch is CancellationError {
            // User cancelled — not an error
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User tapped Cancel on the auth sheet — not an error
        } catch {
            authError = error.localizedDescription
        }

        isAuthenticating = false
    }

    /// Check the current auth status with the backend
    func refreshAuthStatus() async {
        do {
            authState = try await SpotifyService.shared.fetchAuthStatus()
        } catch {
            // If we can't reach the backend, assume disconnected
            authState = .disconnected
        }
    }

    /// Disconnect Spotify
    func disconnect() async {
        do {
            try await SpotifyService.shared.disconnect()
        } catch {
            // Best-effort — clear local state regardless
        }
        authState = .disconnected
    }

    // MARK: - Private Helpers

    /// Build the Spotify /authorize URL with all required query parameters
    private func buildAuthURL() -> URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        return components?.url
    }

    /// Extract the `code` parameter from the OAuth callback URL
    /// e.g. golftrip://spotify-callback?code=AQD...
    private func extractAuthCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }
}
