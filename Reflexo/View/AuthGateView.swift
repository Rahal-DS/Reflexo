//
//  AuthGateView.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 11/10/2025.
//

import SwiftUI

/// A gate screen that prompts the user to **log in** or **register** before
/// accessing the rest of Reflexo.
///
/// `AuthGateView` hosts two tabs:
/// - **Login**: Presents ``LoginView``
/// - **Register**: Presents ``RegisterView``
///
/// ### Behavior
/// - Defaults to the **Login** tab on first appearance.
/// - Child views update `currentPage` (e.g., to ``Route.home``) after success.
/// - Accent color follows the app brand color set as `DarkYellow`.
struct AuthGateView: View {
    @Binding var currentPage: String
    @State private var tab = "login"
    
    var body: some View {
        
        VStack(spacing: 20) {
            Logo()
            
            Text("Please log in or create an account to continue.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            TabView(selection: $tab) {
                LoginView(currentPage: $currentPage)
                    .tabItem {
                        Label("Login", systemImage: "person.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .tag("login")
                RegisterView(currentPage: $currentPage, tabSelection: $tab)
                    .tabItem {
                        Label("Register", systemImage: "person.badge.plus.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .tag("register")
            }
            .accentColor(Color("DarkYellow"))
            .padding(.top, 20)
            
        }
        .background(Color("Beige"))
        
        
    }
}
