//
//  RegisterView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//
import SwiftUI
/// A registration screen that creates a new user account in Firebase Auth and
/// writes a profile document via ``FirebaseManager``.
///
/// ### Overview
/// ``RegisterView`` collects display name, country, date of birth, email, and
/// password. It validates required fields locally, calls ``signUp()`` on submit,
/// shows progress state, and presents a success alert that routes users to the
/// login tab.
///
/// ### Data Flow
/// 1. User fills the **About you** and **Login** sections.
/// 2. Tapping **Create account** triggers ``signUp()``.
/// 3. ``FirebaseManager/signUp(email:password:displayName:country:dobISO:)``
/// creates the Firebase Auth user and persists profile fields.
/// 4. On success, ``showSuccess`` presents an alert that switches to the Login
/// tab by updating ``tabSelection``.
///
/// ### Validation & UX
/// - Disables the submit button unless email & display name are non‑empty and
/// the password is at least 6 characters.
/// - Shows a `ProgressView` while the asynchronous sign‑up is in flight.
/// - Displays user‑friendly errors via ``firebaseAuthMessage(_:)``.
struct RegisterView: View {
    @Binding var currentPage: String
    @Binding var tabSelection: String
    @State private var displayName = ""
    @State private var country = ""
    @State private var dob = Date(timeIntervalSince1970: 915148800) // 1999-01-01
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isBusy = false
    @State private var showSuccess = false
    @EnvironmentObject var fb: FirebaseManager
    
    /// Renders the register form and handles success routing via an alert./
    var body: some View {
        
        VStack(spacing: 20) {
            HeaderView(title: "Register")
            Form {
                Section(header: Text("About you")) {
                    TextField("Display name", text: $displayName).textInputAutocapitalization(.never)
                    TextField("Country", text: $country)
                    DatePicker("Date of birth", selection: $dob, displayedComponents: .date)
                }
                Section(header: Text("Login")) {
                    TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    SecureField("Password (min 6)", text: $password)
                }
                if let e = errorText { Text(e).foregroundColor(.red) }
                Button {
                    Task { await signUp() }
                } label: {
                    HStack(spacing: 8) {
                        if isBusy { ProgressView().tint(.black) }
                        Text(isBusy ? "Creating…" : "Create account")
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
                .disabled(isBusy || email.isEmpty || displayName.isEmpty || password.count < 6)
                .opacity(isBusy || email.isEmpty ||  displayName.isEmpty || password.count < 6 ? 0.6 : 1.0)
                .padding(.horizontal, 30)
            }
            .background(Color.clear)
            .scrollContentBackground(.hidden)
            .formStyle(.grouped)
            
        }
        .background(Color("Beige"))
        .alert("Sign up successful", isPresented: $showSuccess) {
            Button("OK") {
                tabSelection = "login"
            }
        } message: {
            Text("Please sign in.")
        }
        
    }
    
    /// Creates the Firebase account and profile, handling UI flags and errors.
    ///
    /// The date of birth is serialized to **ISO‑8601 full‑date** (YYYY‑MM‑DD)
    /// using `ISO8601DateFormatter` with `.withFullDate`.
    ///
    /// - Effects: On success, sets ``showSuccess`` to `true` (which triggers an
    /// alert that routes users to the Login tab). On failure, sets
    /// ``errorText`` to a friendly message.
    func signUp() async {
        errorText = nil;
        isBusy = true
        do {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withFullDate]
            let dobISO = iso.string(from: dob)
            try await fb.signUp(email: email, password: password, displayName: displayName, country: country, dobISO: dobISO)
            
            showSuccess = true
            
        } catch { errorText = firebaseAuthMessage(error) }
        isBusy = false
    }
}
