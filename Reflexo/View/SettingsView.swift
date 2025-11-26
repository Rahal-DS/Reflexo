//
//  SettingsView.swift
//  Reflexo
//
//  Created by Rahal De Silva on 31/8/2025.
//
import SwiftUI

/// A simple settings screen showing toggles for sound, music, and notifications.
///
/// `SettingsView` displays three options:
/// - **Sound** — turns game sound effects on/off
/// - **Music** — turns background music on/off
/// - **Notifications** — lets the user trigger a test local notification
///
/// This variant keeps state in-memory using `@State` properties. If you want
/// persistence across launches, consider replacing these with `@AppStorage`
/// or an injected settings store.
///
struct SettingsView: View
{
    @Binding var currentPage: String

    /// In-memory flag for enabling/disabling sound effects.
    @State private var _sound = true

    /// In-memory flag for enabling/disabling background music.
    @State private var _music = true

    /// In-memory flag for enabling/disabling notifications (UI only).
    @State private var _notifications = true
    
    var body: some View
    {
        
        VStack(spacing: 20)
        {
            
            HeaderView(title: "Settings")
            
            VStack(spacing: 30)
            {
                /// Toggle card: Sound
                Toggle(isOn: $_sound)
                {
                    Text("Sound")
                        .font(.system(size: 20, design: .rounded))
                        .foregroundColor(Color("DarkOlive"))
                }
                .tint(Color(hex: 0xc49527))
                .frame(maxWidth: 200)
                .padding()
                .background(Color.white.opacity(0.5))
                .cornerRadius(12)
                
                /// Toggle card: Music
                Toggle(isOn: $_music)
                {
                    Text("Music")
                        .font(.system(size: 20, design: .rounded))
                        .foregroundColor(Color("DarkOlive"))
                }
                .tint(Color("DarkYellow"))
                .frame(maxWidth: 200)
                .padding()
                .background(Color.white.opacity(0.5))
                .cornerRadius(12)
                
                /// Toggle card: Notifications
                ///
                /// > Note: This UI flag doesn’t request permission by itself.
                /// To actually schedule notifications, ensure notification
                /// authorization is granted (see `NotificationManager`).
                Toggle(isOn: $_notifications)
                {
                    Text("Notifications")
                        .font(.system(size: 20, design: .rounded))
                        .foregroundColor(Color("DarkOlive"))
                }
                .tint(Color("DarkYellow"))
                .frame(maxWidth: 200)
                .padding()
                .background(Color.white.opacity(0.5))
                .cornerRadius(12)
                
                /// Button that schedules a simple test notification after 5 seconds.
                ///
                /// - Important: This requires notification permission to be granted.
                /// If permission is denied, nothing will be delivered.
                Button {
                    // Fires a local notification in ~5 seconds
                    NotificationManager.shared.scheduleIn(seconds: 5)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                        Text("Send test in 5s")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("DarkYellow"))
                .controlSize(.large)
            }
            
        }
        .padding(.top, 50)
    }
    
}

#Preview
{
    @Previewable @State var page = "Settings"
    SettingsView(currentPage: $page)
}
