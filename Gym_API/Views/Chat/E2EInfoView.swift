//
//  E2EInfoView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Vista informativa sobre la encriptación end-to-end

import SwiftUI

struct E2EInfoView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("End-to-End Encryption")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icono principal
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 20)
                        
                        // Descripción principal
                        Text("Your messages are protected")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                        
                        Text("End-to-end encryption ensures that only you and the person you're chatting with can read the messages.")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Características
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "lock.fill",
                                title: "Private Messages",
                                description: "Nobody else can read your messages, not even us",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "key.fill",
                                title: "Unique Keys",
                                description: "Each conversation has its own encryption keys",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "checkmark.shield.fill",
                                title: "Automatic Verification",
                                description: "Messages are automatically verified to prevent tampering",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "iphone.and.arrow.forward",
                                title: "Multi-device",
                                description: "Your keys sync securely across devices",
                                themeManager: themeManager
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Nota técnica
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                Text("Technical Information")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            
                            Text("We use the Signal protocol with AES-256-GCM encryption and ECDH for key exchange. Private keys never leave your device.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                        .padding(.horizontal, 20)
                        
                        // Limitaciones
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)
                                
                                Text("Current Limitations")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                BulletPoint(text: "Only available in direct chats (1-to-1)", themeManager: themeManager)
                                BulletPoint(text: "Group chats don't have E2E yet", themeManager: themeManager)
                                BulletPoint(text: "Images and files are sent unencrypted", themeManager: themeManager)
                                BulletPoint(text: "History prior to enabling E2E is not encrypted", themeManager: themeManager)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
                .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Bullet Point
struct BulletPoint: View {
    let text: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    E2EInfoView()
        .environmentObject(ThemeManager())
}