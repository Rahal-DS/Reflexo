//
//  HomeView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 30/8/2025.
//
import SwiftUI

/// The main landing screen shown after authentication.
///
/// `HomeView` greets the signed-in user, and presents quick actions to:
/// - Start playing (``Route/games``)
/// - View leaderboards (``Route/leaderboards``)
/// - Manage profile (``Route/profile``)
/// - Open settings (``Route/settings``)
///
/// It also provides a **Sign Out** control that clears the session and returns
/// to the auth gate.
///
/// ### Usage
/// ```swift
/// @State private var currentPage = Route.home
/// HomeView(currentPage: $currentPage)
///     .environmentObject(UserSessionManager())
///     .environmentObject(FirebaseManager())
/// ```
///
/// ### Behavior
/// - Reads ``UserSessionManager`` for the greeting (display name).
/// - On sign out, calls ``FirebaseManager/signOut()`` and routes to ``Route/authGate``.
/// - Displays error alerts for sign-out failures.
struct HomeView: View
{
    @EnvironmentObject var session: UserSessionManager
    @EnvironmentObject var fb: FirebaseManager
    
    @Binding var currentPage: String
    
    @State private var showSignOutConfirm = false
    @State private var errorText: String?
    
    
    var body: some View {
        VStack(spacing: 20) {
            Logo()
            (
                Text("Hi, ")
                    .font(.system(size: 32)) +
                Text(session.displayName)
                    .font(.system(size: 32))
                    .bold()
                    .foregroundColor(Color(hex: 0xc49527))
            )
            .frame(maxWidth: .infinity, alignment: .center) // push to left
            
            Spacer()
                .frame(height: 50)
            
            VStack(spacing: 20) {
                
                HStack(spacing: 20) {
                    SquareButton(label: "Play", color: 0xcfaa51, icon: "play.fill", currentPage: $currentPage,  nextPage: "Games")
                    SquareButton(label: "Leaderboards", color: 0x5c6651, icon: "list.bullet.clipboard", currentPage: $currentPage,  nextPage: Route.leaderboards)
                }
                HStack(spacing: 20) {
                    SquareButton(label: "Your Profile", color: 0x93998d, icon: "person.crop.circle", currentPage: $currentPage,  nextPage: "Profile")
                    SquareButton(label: "Settings", color: 0x4d4b47, icon: "gearshape.fill", currentPage: $currentPage,  nextPage: "Settings",)
                }
            }
            
        }
        
        // Sign out button + dialogs
        Button {
            showSignOutConfirm = true
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color("Olive").opacity(0.12))
                .foregroundColor(Color("DarkOlive"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(radius: 1, y: 1)
        }
        .padding([.top, .trailing], 20)
        .confirmationDialog("Sign out of Reflexo?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: .constant(errorText != nil), actions: {
            Button("OK") { errorText = nil }
        }, message: {
            Text(errorText ?? "")
        })
        
    }
    
    // MARK: - Actions

    /// Signs out the current user and returns to the auth gate.
    ///
    /// On failure, presents a user-readable error message.
    private func signOut() {
        do {
            try fb.signOut()
            currentPage = Route.authGate
        } catch {
            errorText = error.localizedDescription
        }
    }
    
}

