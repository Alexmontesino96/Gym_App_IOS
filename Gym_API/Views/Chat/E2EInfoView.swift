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
                    Text("Encriptación End-to-End")
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
                        Text("Tus mensajes están protegidos")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                        
                        Text("La encriptación end-to-end asegura que solo tú y la persona con quien chateas pueden leer los mensajes.")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Características
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "lock.fill",
                                title: "Mensajes Privados",
                                description: "Nadie más puede leer tus mensajes, ni siquiera nosotros",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "key.fill",
                                title: "Claves Únicas",
                                description: "Cada conversación tiene sus propias claves de encriptación",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "checkmark.shield.fill",
                                title: "Verificación Automática",
                                description: "Los mensajes se verifican automáticamente para evitar alteraciones",
                                themeManager: themeManager
                            )
                            
                            FeatureRow(
                                icon: "iphone.and.arrow.forward",
                                title: "Multi-dispositivo",
                                description: "Tus claves se sincronizan de forma segura entre dispositivos",
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
                                
                                Text("Información Técnica")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            
                            Text("Utilizamos el protocolo Signal con cifrado AES-256-GCM y ECDH para el intercambio de claves. Las claves privadas nunca salen de tu dispositivo.")
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
                                
                                Text("Limitaciones Actuales")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                BulletPoint(text: "Solo disponible en chats directos (1 a 1)", themeManager: themeManager)
                                BulletPoint(text: "Los chats de grupo aún no tienen E2E", themeManager: themeManager)
                                BulletPoint(text: "Las imágenes y archivos se envían sin encriptar", themeManager: themeManager)
                                BulletPoint(text: "El historial previo a activar E2E no está encriptado", themeManager: themeManager)
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