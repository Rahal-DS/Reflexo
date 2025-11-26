//
//  ProfileView.swift
//  Reflexo
//
//  Created by Rahal De Silva on 31/8/2025.
//
import SwiftUI
import SwiftData

/// Displays the signed-in user’s profile and per-game statistics.
///
/// `ProfileView` reads identity and session data from ``UserSessionManager``
/// and surfaces locally computed stats (via ``ProfileViewModel``) for each game.
/// If the user is not signed in, it shows a gentle prompt; if loading fails,
/// it offers a retry.
///
/// ### Behavior
/// - Triggers ``ProfileViewModel/load(using:context:)`` on appear.
/// - Shows progress while loading, an inline error with **Retry** on failure,
///   or the profile fields + per-game stats on success.
/// - Stats are computed from local SwiftData using
///   ``ProfileViewModel/computeUserTopScore(gameName:context:)`` and
///   ``ProfileViewModel/computeUserTopAccuracy(gameName:context:)`` (Aim Trainer only).
///
struct ProfileView: View {
    @Binding var currentPage: String
    @EnvironmentObject var fb: FirebaseManager
    @EnvironmentObject var session: UserSessionManager
    @Environment(\.modelContext) private var context
    @StateObject private var vm = ProfileViewModel()
    
    /// Canonical list of games to summarize in the statistics section.
    let games = ["ReactionTime", "AimTrainer", "VerbalMemory", "PatternRecognition"]
    
    var body: some View {
        VStack(spacing: 20) {
            Logo()
            HeaderView(title: "Your Profile")
            
            // Profile card (loading / error / content states)
            Group {
                if vm.isLoading {
                    ProgressView("Loading your profile…")
                } else if let err = vm.errorText {
                    VStack(spacing: 8) {
                        Text("Couldn’t load profile").font(.headline)
                        Text(err).font(.footnote).foregroundColor(.secondary)
                        Button("Retry") { vm.load(using: fb, context: context) }
                            .buttonStyle(.plain)
                    }
                } else if fb.currentUser == nil {
                    VStack(spacing: 6) {
                        Text("Not signed in").font(.headline)
                        Text("Please sign in to view your profile.")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 10) {
                        ProfileFieldRow(label: "Username", value: session.displayName)
                        ProfileFieldRow(label: "Email",    value: session.email)
                        ProfileFieldRow(label: "Date of birth",      value: session.profile?.dob ?? "-")
                    }
                }
            }
            .card()

            // Statistics card
            Text("Your statistics")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Group {
                ScrollView {
                    ForEach(games, id: \.self) { game in
                        // Safely call your throwing helpers
                        let topScore = try? vm.computeUserTopScore(gameName: game, context: context)
                        let topAcc: Float? = try? vm.computeUserTopAccuracy(gameName: game, context: context)
                        
                        VStack(spacing: 4) {
                            Text(game).font(.headline)
                            Text("Top score: \(topScore ?? 0)").font(.subheadline)
                            
                            if game == "AimTrainer", let acc = topAcc {
                                Text(String(format: "Top accuracy: %.1f%%", acc))
                            }
                        }
                        .padding()
                    }
                }
            }
            .card()
        }
        .task {
            await vm.load(using: fb, context: context)
        }
        .background(Color("Beige"))
    }
}



// MARK: - Subviews

/// A single labeled profile field row (e.g., “Email: user@host”).
///
/// Fixed label width keeps values aligned; values support multiline wrapping.

private struct ProfileFieldRow: View {
    let label: String
    let value: String
    var labelWidth: CGFloat = 110   // tweak to taste
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(label):")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(width: labelWidth, alignment: .leading)
            
            Text(value)
                .font(.system(size: 18, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var page = "Profile"
    ProfileView(currentPage: $page)
}


