# Solución: Dispositivo Unsubscribed en OneSignal

## Problema
El dashboard de OneSignal muestra:
- Audience: 1
- Unsubscribed: 1
- Delivered: 0

## Causas Comunes

### 1. **Simulador de iOS**
- ❌ Las notificaciones push NO funcionan en el simulador
- ✅ DEBES probar en un dispositivo físico real

### 2. **Permisos Rechazados**
- El usuario rechazó los permisos de notificaciones
- Los permisos fueron revocados en Ajustes > Notificaciones

### 3. **Token APNs Inválido**
- El certificado o auth key no está configurado correctamente
- El entorno (development/production) no coincide

## Soluciones Implementadas

### 1. **Mejoras en OneSignalService**
```swift
// Verificación automática de permisos
func checkNotificationPermissionStatus()

// Re-suscripción manual
func manuallyOptIn()

// Logs detallados del estado
func checkSubscriptionStatus()
```

### 2. **UI de Control en Profile**
- Indicador visual del estado (verde/rojo)
- Botón "Activar" para re-suscribirse manualmente
- Muestra el Player ID para debugging

### 3. **Configuración de Entitlements**
```xml
<key>aps-environment</key>
<string>development</string>
```

## Pasos para Solucionar

### 1. **En Dispositivo Real**
1. Instala la app en un iPhone/iPad físico
2. Acepta los permisos cuando se soliciten
3. Verifica en Profile > Push Notifications que esté "Activado"

### 2. **Si Aparece "Desactivado"**
1. Toca el botón "Activar" en la app
2. Ve a Ajustes > Notificaciones > Gym_API
3. Activa "Permitir notificaciones"
4. Regresa a la app y toca "Activar" nuevamente

### 3. **Verificar en OneSignal Dashboard**
1. Espera 30-60 segundos
2. Refresca el dashboard
3. El dispositivo debería aparecer como "Subscribed"

### 4. **Debug con Logs**
En la consola de Xcode verás:
```
🔔 Inicializando OneSignal...
🔔 Estado actual de permisos: true/false
🔔 Estado de suscripción:
   - Suscrito: true/false
   - ID de suscripción: xxxxx
   - Token: xxxxx
```

## Verificación Final

### Desde OneSignal Dashboard:
1. Ve a Audience > All Users
2. Busca tu dispositivo por Player ID
3. Verifica que el estado sea "Subscribed"

### Enviar Notificación de Prueba:
1. Messages > New Push
2. Send to Subscribed Users
3. Title: "Test"
4. Message: "¡Funciona!"
5. Send Now

## Notas Importantes

- **Desarrollo**: Usa un dispositivo físico con build de desarrollo
- **Producción**: Cambia `aps-environment` a "production" antes de subir a App Store
- **Certificados**: Asegúrate que el .p8 key esté activo en Apple Developer