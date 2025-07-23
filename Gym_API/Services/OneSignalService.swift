//
//  OneSignalService.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/22/25.
//

import Foundation
import OneSignalFramework

class OneSignalService: ObservableObject {
    static let shared = OneSignalService()
    
    private let appId = "57c2285f-1a1a-4431-a5db-7ecd0bab4c5f"
    
    private init() {}
    
    func initialize() {
        print("🔔 Inicializando OneSignal...")
        
        // Remove this method to stop OneSignal Debugging
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        
        // OneSignal initialization
        OneSignal.initialize(appId, withLaunchOptions: nil)
        
        // Check current permission status first
        checkNotificationPermissionStatus()
        
        print("✅ OneSignal inicializado correctamente")
    }
    
    func checkNotificationPermissionStatus() {
        print("🔔 Verificando estado de permisos de notificaciones...")
        
        // Check if already has permission
        let hasPermission = OneSignal.Notifications.permission
        print("🔔 Estado actual de permisos: \(hasPermission)")
        
        if !hasPermission {
            // Request permission if not granted
            requestNotificationPermission()
        } else {
            // Check subscription status
            checkSubscriptionStatus()
        }
    }
    
    func requestNotificationPermission() {
        print("🔔 Solicitando permisos de notificaciones...")
        
        OneSignal.Notifications.requestPermission({ accepted in
            print("🔔 Usuario aceptó notificaciones: \(accepted)")
            
            if accepted {
                // If accepted, check subscription
                self.checkSubscriptionStatus()
            } else {
                print("❌ Usuario rechazó las notificaciones")
            }
        }, fallbackToSettings: true)
    }
    
    func checkSubscriptionStatus() {
        let isSubscribed = OneSignal.User.pushSubscription.optedIn
        let subscriptionId = OneSignal.User.pushSubscription.id
        let token = OneSignal.User.pushSubscription.token
        
        print("🔔 Estado de suscripción:")
        print("   - Suscrito: \(isSubscribed)")
        print("   - ID de suscripción: \(subscriptionId ?? "nil")")
        print("   - Token: \(token ?? "nil")")
        
        if !isSubscribed && OneSignal.Notifications.permission {
            print("⚠️ Tiene permisos pero no está suscrito. Intentando re-suscribir...")
            OneSignal.User.pushSubscription.optIn()
        }
    }
    
    func manuallyOptIn() {
        print("🔔 Suscribiendo manualmente...")
        OneSignal.User.pushSubscription.optIn()
        checkSubscriptionStatus()
    }
    
    func setExternalUserId(_ userId: String) {
        print("🔔 Configurando External User ID: \(userId)")
        OneSignal.login(userId)
    }
    
    func logout() {
        print("🔔 Cerrando sesión de OneSignal")
        OneSignal.logout()
    }
    
    func sendTag(key: String, value: String) {
        print("🔔 Enviando tag: \(key) = \(value)")
        OneSignal.User.addTag(key: key, value: value)
    }
    
    func removeTag(key: String) {
        print("🔔 Removiendo tag: \(key)")
        OneSignal.User.removeTag(key)
    }
    
    func getPlayerId() -> String? {
        return OneSignal.User.pushSubscription.id
    }
    
    func isSubscribed() -> Bool {
        return OneSignal.User.pushSubscription.optedIn
    }
}