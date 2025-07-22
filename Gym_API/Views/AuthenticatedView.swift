//
//  AuthenticatedView.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import SwiftUI

struct AuthenticatedView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(themeManager)
            } else {
                LoginViewDirect()
                    .environmentObject(themeManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
} 