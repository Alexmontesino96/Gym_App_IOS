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
    
    private let appId: String
    private let hasRequestedPushKey = "hasRequestedPushPermission"

    private init() {
        // Leer AppId desde Info.plist de forma segura
        if let appIdFromBundle = Bundle.main.object(forInfoDictionaryKey: "ONESIGNAL_APP_ID") as? String,
           !appIdFromBundle.isEmpty {
            self.appId = appIdFromBundle
        } else {
            // En desarrollo, usar un valor por defecto (que debe ser reemplazado)
            #if DEBUG
            print("⚠️ OneSignal App ID no configurado en Info.plist, usando valor de desarrollo")
            self.appId = "dev-app-id-not-configured"
            #else
            fatalError("❌ OneSignal App ID debe estar configurado en Info.plist para producción")
            #endif
        }
    }
    
    func initialize() {
        print("🔔 Inicializando OneSignal...")
        
        // Validar App ID antes de inicializar
        guard !appId.isEmpty else {
            print("❌ OneSignal App ID está vacío")
            return
        }
        
        do {
            // Solo habilitar debug logging en desarrollo
            #if DEBUG
            OneSignal.Debug.setLogLevel(.LL_VERBOSE)
            #endif

            // OneSignal initialization con try-catch implícito
            OneSignal.initialize(appId, withLaunchOptions: nil)
            
            // Check current permission status first
            checkNotificationPermissionStatus()
            
            print("✅ OneSignal inicializado correctamente")
        } catch {
            print("❌ Error al inicializar OneSignal: \(error)")
        }
    }
    
    func checkNotificationPermissionStatus() {
        print("🔔 Verificando estado de permisos de notificaciones...")
        // Usar API nativa para estado preciso y evitar prompts repetidos
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let status = settings.authorizationStatus
                let alreadyRequested = UserDefaults.standard.bool(forKey: self.hasRequestedPushKey)
                print("🔔 Estado nativo: \(status.rawValue), alreadyRequested=\(alreadyRequested)")
                
                switch status {
                case .authorized, .provisional, .ephemeral:
                    self.checkSubscriptionStatus()
                case .denied:
                    // No volver a solicitar automáticamente si el usuario negó
                    print("❌ Notificaciones denegadas; no se solicitará automáticamente")
                case .notDetermined:
                    // Solicitar solo una vez de forma automática
                    if !alreadyRequested {
                        self.requestNotificationPermission()
                        UserDefaults.standard.set(true, forKey: self.hasRequestedPushKey)
                    } else {
                        print("⏭️ Permiso de notificaciones no determinado pero ya solicitado antes; esperando acción del usuario")
                    }
                @unknown default:
                    break
                }
            }
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

    deinit {
        #if DEBUG
        print("🗑️ OneSignalService deinitialized")
        #endif
    }
}
