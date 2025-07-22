#!/bin/bash

echo "🔧 Agregando dependencias de Auth0 y JWTDecode al proyecto..."

# Ruta del proyecto
PROJECT_PATH="Gym_API.xcodeproj"

# Verificar que el proyecto existe
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ No se encontró el proyecto en $PROJECT_PATH"
    exit 1
fi

echo "📋 Instrucciones para agregar dependencias manualmente en Xcode:"
echo ""
echo "1. Abrir el proyecto en Xcode:"
echo "   open $PROJECT_PATH"
echo ""
echo "2. Seleccionar el proyecto 'Gym_API' en el navegador"
echo ""
echo "3. Ir a la pestaña 'Package Dependencies'"
echo ""
echo "4. Hacer clic en el botón '+' para agregar dependencias"
echo ""
echo "5. Agregar las siguientes dependencias:"
echo "   - Auth0 SDK: https://github.com/auth0/Auth0.swift"
echo "   - JWTDecode: https://github.com/auth0/JWTDecode.swift"
echo ""
echo "6. Para cada dependencia:"
echo "   - Pegar la URL del repositorio"
echo "   - Seleccionar 'Up to Next Major Version'"
echo "   - Hacer clic en 'Add Package'"
echo "   - Seleccionar 'Auth0' y 'JWTDecode' respectivamente"
echo "   - Hacer clic en 'Add Package'"
echo ""
echo "7. Después de agregar ambas dependencias, compilar el proyecto"
echo ""
echo "⚡ Dependencias requeridas:"
echo "   - Auth0.swift: Para autenticación"
echo "   - JWTDecode.swift: Para decodificar tokens JWT"
echo ""
echo "✅ Una vez agregadas las dependencias, el proyecto debería compilar sin errores" 