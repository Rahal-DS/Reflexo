//
//  FirebaseManager.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

/// A main-actor Firebase façade that centralizes **Auth**, **Firestore**, and **widget syncing**
/// for the Reflexo app.
///
/// Responsibilities:
/// - Keeps an observable `currentUser` (FirebaseAuth.User) in sync with Auth state changes.
/// - Creates and fetches the user profile document (`/users/{uid}`).
/// - Enforces unique display names via a `/handles/{key}` doc.
/// - Saves high scores using **transactional upserts** (per-user, per-game).
/// - Loads leaderboards and the current user’s best score.
/// - Updates app group `UserDefaults` + reloads widgets when auth state changes.
///
/// ### Usage
/// ```swift
/// @StateObject private var fb = FirebaseManager.shared
///
/// // App start:
/// fb.startAuthListener()
///
/// // Sign up:
/// try await fb.signUp(
///   email: "a@b.com", password: "••••••••",
///   displayName: "asmiyahasan", country: "AU", dobISO: "2000-01-01"
/// )
///
/// // Save a score:
/// try await fb.saveHighScore(game: "Reaction", score: 245, rankScore: 245, accuracy: 100)
///
/// // Leaderboard:
/// let top = try await fb.getTopScores(game: "Reaction", limit: 25)
/// ```
///
/// - Important: This type is `@MainActor` and intended to be used from the main thread.
///   Firestore and Auth calls are bridged with `async/await`.
@MainActor
final class FirebaseManager: ObservableObject {
    /// Global shared instance for app-wide access.
    static let shared = FirebaseManager()
    private let session = UserSessionManager.shared
    private init() {}
    
    /// Currently signed-in Firebase `User` (or `nil` if signed out).
    @Published var currentUser: User? = Auth.auth().currentUser
    
    /// Cached copy of the current user’s profile document (`/users/{uid}`), if loaded.
    @Published var myProfile: AppUser?
    
    // MARK: Firebase Internals
    private let db = Firestore.firestore()
    private var profileListener: ListenerRegistration?
    private var handle: AuthStateDidChangeListenerHandle?
    
    // MARK: Auth Lifecycle
    
    /// Starts listening for Firebase Auth state changes.
    ///
    /// When the user changes, this:
    /// - updates ``currentUser``,
    /// - writes the `uid` into the app-group `UserDefaults` (`group.com.ReflexoShared`),
    /// - reloads all widget timelines (`WidgetCenter.shared.reloadAllTimelines()`).
    ///
    /// Call once during app launch (e.g., in `App`/`Scene` startup).
    func startAuthListener() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            
            let defaults = UserDefaults(suiteName: "group.com.ReflexoShared")
            if let uid = user?.uid {
                defaults?.set(uid, forKey: "currentUserUID")
            } else {
                defaults?.removeObject(forKey: "currentUserUID")
            }
            
            WidgetCenter.shared.reloadAllTimelines()
        }
        
    }
    
    deinit { if let h = handle { Auth.auth().removeStateDidChangeListener(h) } }
    
    // MARK: - Account Management
    
    /// Creates a Firebase Auth user and a corresponding profile document, while reserving a unique handle.
    ///
    /// Flow:
    /// 1. Validate and normalize the `displayName` to a lowercase key (see ``HandleValidator``).
    /// 2. Create the Auth user (`createUser`).
    /// 3. Claim the handle by writing `/handles/{key}` (fail if exists).
    /// 4. Create/update `/users/{uid}` with profile fields and timestamps.
    /// 5. On any error, attempt to delete the newly created Auth user (cleanup) and rethrow.
    ///
    /// - Parameters:
    ///   - email: User’s email for Auth.
    ///   - password: Password for Auth.
    ///   - displayName: Public display handle; must match allowed characters.
    ///   - country: ISO-like country string (app-defined).
    ///   - dobISO: Date of birth in `yyyy-MM-dd` format.
    /// - Throws: ``HandleError`` for invalid/taken names, Firebase Auth/Firestore errors otherwise.
    func signUp(email: String,
                password: String,
                displayName: String,
                country: String,
                dobISO: String) async throws
    {
        let key = try HandleValidator.normalizeAndValidate(displayName)
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        
        
        do {
            let handleRef = db.collection("handles").document(key)
            
            if try await handleRef.getDocument().exists {
                throw HandleError.nameTaken
            }
            
            try await handleRef.setData([
                "uid": uid,
                "key": key,
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            // 3) Create /users/{uid}
            let profile = AppUser(
                id: nil, uid: uid, email: email,
                displayName: displayName, country: country, dob: dobISO,
                createdAt: nil, updatedAt: nil
            )
            
            try await db.collection("users").document(uid).setData(from: profile, merge: true)
            try await db.collection("users").document(uid).setData([
                "displayName": displayName,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            let original = error
            do {
                try await result.user.delete()
            } catch {
                throw error
            }
            throw original
        }
    }
    
    /// Signs in with email/password credentials.
    ///
    /// On success, the auth listener will publish the new user and refresh widgets.
    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    /// Signs out the current user, clears shared `UserDefaults` state, and reloads widgets.
    ///
    /// - Throws: Any error from `Auth.auth().signOut()`.
    func signOut() throws {
        UserDefaults(suiteName: "group.com.ReflexoShared")?
            .removeObject(forKey: "currentUserUID")
        try Auth.auth().signOut()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    
    // MARK: - Profiles

    /// Loads the current user’s profile document (`/users/{uid}`).
    ///
    /// - Returns: The decoded ``AppUser``.
    /// - Throws: ``AuthError/notSignedIn`` if there is no current user or
    ///   ``AuthError/missingProfile`` if decoding fails or the doc is absent.
    func fetchMyProfile() async throws -> AppUser {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.notSignedIn }
        let snap = try await db.collection("users").document(uid).getDocument()
        if let user = try? snap.data(as: AppUser.self) { return user }
        throw AuthError.missingProfile
    }
    
    // MARK: - Save a high score
    func saveHighScore(game: String, score: Int, rankScore: Int, accuracy: Int) async throws {
        print("Attempting to save high score for game:", game)

        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.notSignedIn }
        let displayName = try await db.collection("users").document(uid).getDocument(as: AppUser.self).displayName
        
        let docId = "\(uid)_\(game)"
        let ref = db.collection("scores").document(docId)
        
        try await db.runTransaction { txn, _ in
            let snap = try? txn.getDocument(ref)
            
            if let snap, snap.exists {
                let data = snap.data() ?? [:]
                let currentBest = data["rankScore"] as? Int ?? Int.max
                guard rankScore < currentBest else { return nil }
                
                txn.updateData([
                    "score": score,
                    "rankScore": rankScore,
                    "accuracy": accuracy,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            } else {
                txn.setData([
                    "uid": uid,
                    "displayName": displayName,
                    "game": game,
                    "score": score,
                    "rankScore": rankScore,
                    "accuracy": accuracy,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
            }
            return nil
        }
    }
    
    // MARK: - Leaderboard (top N fastest)
    func getTopScores(game: String, limit: Int = 25) async throws -> [HighScore] {
        let q = db.collection("scores")
            .whereField("game", isEqualTo: game)
            .order(by: "rankScore", descending: false)
            .limit(to: limit)
        let snap = try await q.getDocuments()
        return snap.documents.compactMap { try? $0.data(as: HighScore.self) }
    }
    
    // MARK: - My best score
    func getMyBestScore(game: String) async throws -> HighScore? {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthError.notSignedIn }
        let q = db.collection("scores")
            .whereField("game", isEqualTo: game)
            .whereField("uid", isEqualTo: uid)
        let snap = try await q.getDocuments()
        return snap.documents.first.flatMap { try? $0.data(as: HighScore.self) }
    }
    
}

// MARK: - Errors

/// Errors specific to app-level auth flows.
enum AuthError: LocalizedError {
    case notSignedIn
    case missingProfile
    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to sign in."
        case .missingProfile: return "Profile not found."
        }
    }
}

/// Converts Firebase Auth `NSError`s into concise, user-facing messages.
///
/// Pass any `Error`; if it’s not an Auth error, the function returns `error.localizedDescription`.
/// For Auth errors, it maps known `AuthErrorCode`s to friendly strings.
///
/// - Parameter error: An `Error` potentially originating from Firebase Auth.
/// - Returns: A user-friendly error message.
func firebaseAuthMessage(_ error: Error) -> String {
    let ns = error as NSError
    // Only handle Firebase Auth errors as documented
    guard ns.domain == AuthErrorDomain else { return error.localizedDescription }
    
    // Wrap to get the typed enum; this is the most reliable pattern
    let authErr = AuthErrorCode(_bridgedNSError: ns)
    
    switch authErr?.code {
        // Common to many methods
    case .networkError:          return "Network error. Please check your connection."
    case .tooManyRequests:       return "Too many attempts. Try again later."
    case .userDisabled:          return "This account has been disabled."
    case .operationNotAllowed:   return "This sign-in method is disabled. Contact support."
        
        // Email/password sign up
    case .invalidEmail:          return "Invalid email address."
    case .emailAlreadyInUse:     return "That email is already registered."
    case .weakPassword:          return "Password must be stronger."
        
        // Email/password sign in
    case .wrongPassword:         return "Incorrect password."
    case .userNotFound:          return "No account found with that email."
        
        // Provider/linking (optional but common)
    case .credentialAlreadyInUse: return "These credentials are already linked to another account."
    case .invalidCredential:      return "The credential is malformed or has expired."
    case .providerAlreadyLinked:  return "That sign-in provider is already linked."
        
    default:
        // Fall back to Firebase’s own localized message
        return ns.localizedDescription
    }
}

// MARK: - Handle Validation

/// Validates and normalizes a display name for use as a **unique handle key**.
///
/// Rules:
/// - Lowercased
/// - Allowed characters: `a–z`, `0–9`, `.`, `_`, `-`
///
/// - Parameter raw: The user-entered display name.
/// - Returns: The normalized, lowercased key if valid.
/// - Throws: ``HandleError/invalidName`` if it fails validation.
enum HandleValidator {
    /// Returns a **lowercased** handle key if valid; otherwise throws.
    static func normalizeAndValidate(_ raw: String) throws -> String {
        let key = raw.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        guard !key.isEmpty, key.unicodeScalars.allSatisfy(allowed.contains) else {
            throw HandleError.invalidName
        }
        return key
    }
}

/// Errors related to handle uniqueness and formatting.
enum HandleError: LocalizedError {
    case nameTaken, invalidName
    var errorDescription: String? {
        switch self {
        case .nameTaken:   return "That name is taken."
        case .invalidName: return "Please choose a different name."
        }
    }
}

