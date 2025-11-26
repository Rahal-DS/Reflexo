//
//  LoginView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//

import Foundation
import SwiftUI

/// The email/password sign-in screen.
///
/// `LoginView` collects credentials, calls ``FirebaseManager/signIn(email:password:)``,
/// and routes to ``Route/home`` on success. Errors are shown inline above the action button.
///
/// ### Usage
/// ```swift
/// @State private var route = Route.login
/// LoginView(currentPage: $route)
///     .environmentObject(FirebaseManager.shared)
/// ```
///
/// ### Behavior
/// - Disables the **Sign In** button if fields are invalid or a request is in flight.
/// - Shows a spinner while awaiting Firebase.
/// - Uses keyboard **Return** to advance focus and submit on the password field.
struct LoginView: View {
    /// User's email address input.
    @State private var email = ""
    
    /// User's password input.
    @State private var password = ""
    
    /// Optional error message from the last sign-in attempt.
    @State private var errorText: String?
    
    /// Whether a sign-in request is currently running.
    @State private var isBusy = false
    
    // MARK: - Environment & Routing

    /// Firebase facade providing `signIn`
    @EnvironmentObject var fb: FirebaseManager
    
    /// Binding to the parent route; set to ``Route/home`` on success.
    @Binding var currentPage: String
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            HeaderView(title: "Login")
            
            Form {
                Section(header: Text("Email & Password")) {
                    TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }
                if let e = errorText { Text(e).foregroundColor(.red) }
                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 8) {
                        if isBusy { ProgressView().tint(.black) }
                        Text(isBusy ? "Signing in…" : "Sign In")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)                 // full-width
                    .padding(.vertical, 14)
                    .background(Color("DarkYellow"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.clear)
                .buttonStyle(.plain)
                .disabled(isBusy || email.isEmpty || password.count < 6)
                .opacity(isBusy || email.isEmpty || password.count < 6 ? 0.6 : 1.0)
                .padding(.horizontal, 30)
                
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            //            .formStyle(.grouped)
        }
        .background(Color("Beige"))
        
    }
    
    // MARK: - Actions

    /// Attempts to sign in with the provided credentials.
    ///
    /// On success, routes to ``Route/home``.
    /// On failure, sets ``errorText`` with a user-readable message.
    func signIn() async {
        errorText = nil; isBusy = true
        do {
            try await fb.signIn(email: email, password: password)
            currentPage = Route.home
        }
        catch { errorText = firebaseAuthMessage(error) }
        isBusy = false
    }
}
//
//#Preview
//{
//    LoginView()
//}
