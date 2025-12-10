import SwiftUI

// MARK: - Unified Chat View
/// Vista de chat que usa el sistema optimizado
struct UnifiedChatView: View {
    let conversationId: String
    let conversationName: String
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        // Usar la nueva vista optimizada
        OptimizedChatView(
            conversationId: conversationId,
            conversationName: conversationName
        )
        .id(conversationId) // ✅ CRÍTICO: Fuerza recrear la vista cuando cambia conversationId
        .environmentObject(themeManager)
    }
}

// MARK: - Preview
struct UnifiedChatView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedChatView(
            conversationId: "test_conversation",
            conversationName: "Chat de Prueba"
        )
        .environmentObject(ThemeManager())
    }
}