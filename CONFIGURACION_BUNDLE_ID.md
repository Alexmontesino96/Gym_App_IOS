# Configuración Bundle ID Corregida

## Bundle ID Correcto
- **Bundle ID**: `com.alexmontesino.gymapi`
- **Team ID**: `3N4T4H2H2F`

## Cambios Realizados

### 1. Xcode Project
✅ Actualizado de `Alex.Gym-API` a `com.alexmontesino.gymapi`

### 2. Auth0 Configuration
Asegúrate de actualizar en el dashboard de Auth0:

**Allowed Callback URLs:**
```
com.alexmontesino.gymapi://dev-gd5crfe6qbqlu23p.us.auth0.com/ios/com.alexmontesino.gymapi/callback
```

**Allowed Logout URLs:**
```
com.alexmontesino.gymapi://dev-gd5crfe6qbqlu23p.us.auth0.com/ios/com.alexmontesino.gymapi/callback
```

### 3. OneSignal Configuration
En el dashboard de OneSignal, actualiza:
- **Bundle ID**: `com.alexmontesino.gymapi`
- **Team ID**: `3N4T4H2H2F` (sin cambios)

### 4. Apple Developer Portal
Verifica que el App ID esté configurado con:
- **Bundle ID**: `com.alexmontesino.gymapi`
- **Capabilities**: Push Notifications ✅

## URL Schemes en Info.plist
Si usas URL schemes personalizados, deben ser:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.alexmontesino.gymapi</string>
        </array>
    </dict>
</array>
```

## Verificación

1. **Clean Build Folder**: Cmd+Shift+K
2. **Delete Derived Data**: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. **Rebuild**: Cmd+B

## Importante
- El Bundle ID debe coincidir en TODOS los servicios:
  - ✅ Xcode Project
  - ✅ Apple Developer Portal
  - ✅ OneSignal
  - ✅ Auth0
  - ✅ Certificados APNs