import SwiftUI

struct StreamConnectionTestView: View {
    @ObservedObject private var chatService = ChatService.shared
    @EnvironmentObject var authService: AuthServiceDirect
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Encabezado
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("GetStream Connection Test")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Prueba la conexión con GetStream usando el token de la API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                Divider()
                
                // Estado actual
                VStack(spacing: 12) {
                    if chatService.isTestingConnection {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Probando conexión...")
                                .font(.body)
                        }
                    } else if let result = chatService.connectionTestResult {
                        HStack {
                            Image(systemName: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.contains("✅") ? .green : .red)
                            
                            Text(result)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(result.contains("✅") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                    } else {
                        Text("Presiona el botón para probar la conexión")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                // Información del token
                if let token = chatService.streamToken {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Token Information:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key: \(token.apiKey)")
                                .font(.caption.monospaced())
                            
                            Text("User ID: \(token.internalUserId)")
                                .font(.caption.monospaced())
                            
                            Text("Token: \(String(token.token.prefix(20)))...")
                                .font(.caption.monospaced())
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // Botón de prueba
                Button(action: {
                    Task {
                        await chatService.testGetStreamConnection()
                    }
                }) {
                    HStack {
                        if chatService.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        
                        Text(chatService.isTestingConnection ? "Probando..." : "Probar Conexión")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(chatService.isTestingConnection ? Color.gray : Color.blue)
                    )
                }
                .disabled(chatService.isTestingConnection)
                .padding(.horizontal)
                
                // Botón para limpiar resultado
                if chatService.connectionTestResult != nil {
                    Button("Limpiar Resultado") {
                        chatService.connectionTestResult = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
            }
            .padding()
            .navigationTitle("Stream Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Configurar el authService para ChatService
            chatService.authService = authService
        }
    }
}

#Preview {
    StreamConnectionTestView()
        .environmentObject(AuthServiceDirect())
}