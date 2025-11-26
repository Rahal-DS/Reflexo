//
//  ContentView.swift
//  Reflexo
//
//  Created by Rahal De Silva on 30/8/2025.
//

import SwiftUI

/// The root container of Reflexo.
///
/// `ContentView`:
/// - Starts the Firebase auth listener on appear.
/// - Chooses an initial route (``Route/authGate`` or ``Route/home``).
/// - Renders the active screen via a `switch` over ``Route`` strings.
/// - Shows a bottom navigation bar on non-game app pages.
struct ContentView: View
{
    // MARK: - Environment

    /// Provides Firebase auth state and operations.
    @EnvironmentObject var fb: FirebaseManager
    
    // MARK: - Routing

    /// The current route displayed by the root container.
    @State private var currentPage = Route.home
    
    var body: some View {
        main
            .onAppear {
#if DEBUG
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    currentPage = Route.home
                    return
                }
#endif
                
                fb.startAuthListener()
                currentPage = (fb.currentUser == nil) ? Route.authGate : Route.home
            }
        
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Beige"))
            .ignoresSafeArea()
    }
    // MARK: - Main Switch
    @ViewBuilder
    private var main: some View {
        VStack {
            switch currentPage {
                
            case Route.authGate:
                AuthGateView(currentPage: $currentPage)
                
            case Route.login:
                LoginView(currentPage: $currentPage)
                
            case Route.home:
                HomeView(currentPage: $currentPage)
                
            case Route.games:
                GamesView(currentPage: $currentPage)
                
            case Route.profile:
                ProfileView(currentPage: $currentPage)
                
            case Route.settings:
                SettingsView(currentPage: $currentPage)
                
            case Route.leaderboards:
                ScoreboardView(currentPage: $currentPage)
                
            case Route.reactionTimeLeaderboard:
                ReactionTimeLeaderboardView(currentPage: $currentPage)
                
            case Route.verbalMemoryLeaderboard:
                VerbalMemoryLeaderboardView(currentPage: $currentPage)
                
            case Route.aimTrainerLeaderboard:
                AimTrainerLeaderboardView(currentPage: $currentPage)
                
            case Route.patternRecognitionLeaderboard:
                PatternRecognitionLeaderboardView(currentPage: $currentPage)
                
            case Route.reactionTime:
                ReactionTimeGameView(currentPage: $currentPage)
                
            case Route.aimTrainer:
                AimTrainerView(currentPage: $currentPage)
                
            case Route.verbalMemory:
                VerbalMemoryView(currentPage: $currentPage)
                
            case Route.patternRecognition:
                PatternRecognitionView(currentPage: $currentPage)

            default:
                HomeView(currentPage: $currentPage)
            }
            
            Spacer()
            
            if showsBottomBar(for: currentPage) {
                NavigationBar(currentPage: $currentPage)
                    .padding(.bottom, 0)
            }
        }
        
    }
    // MARK: - Helpers

    /// Whether the bottom navigation should be visible for the given page.
    ///
    /// - Parameter page: A route string.
    /// - Returns: `true` for standard app pages, `false` for games or gates.
    private func showsBottomBar(for page: String) -> Bool {
        !(page == Route.home || page == Route.authGate || Route.isGame(page))
    }
}

// MARK: - Bottom Navigation

/// A simple bottom navigation bar for primary app sections.
///
/// Buttons update the parent's `currentPage` using ``Route`` constants.
/// This avoids stringly-typed routing bugs.
///
/// ### Buttons
/// - Home (``Route/home``)
/// - Profile (``Route/profile``)
/// - Leaderboards (``Route/leaderboards``)
/// - Settings (``Route/settings``)
struct NavigationBar: View
{
    /// Binding to the global route. Updated when a tab is tapped.
    @Binding var currentPage: String
    
    var body: some View
    {
        HStack(spacing: 50)
        {
            Button(action: { currentPage = "Home"})
            {
                VStack
                {
                    Image(systemName: "house.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("Grey"))
                }
            }
            
            Button(action: { currentPage = "Profile"})
            {
                VStack
                {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("Grey"))
                    
                }
            }
            
            Button(action: { currentPage = "Leaderboards"})
            {
                VStack
                {
                    Image(systemName: "list.bullet.clipboard")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("Grey"))
                }
            }
            
            Button(action: { currentPage = "Settings"})
            {
                VStack
                {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color("Grey"))
                    
                }
            }
        }
        .padding()
        .cornerRadius(25)
        .padding(.horizontal, 100)
    }
}

#Preview
{
    ContentView()
        .environmentObject(FirebaseManager.shared)
        .environmentObject(UserSessionManager.shared)
}
// MARK: - Brand Logo


struct Logo: View {
    var body: some View {
        Text("reflexo")
            .font(.system(size: 40, design: .rounded))
            .foregroundColor(Color("DarkOlive"))
            .tracking(4)
            .padding(.top, 80)
    }
}


