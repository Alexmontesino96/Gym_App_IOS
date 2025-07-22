#!/bin/bash

# Script para agregar StreamChat SDK al proyecto Gym_API
# Evita problemas de corrupción del archivo project.pbxproj

echo "🔧 Agregando StreamChat SDK al proyecto..."

# Abrir Xcode y agregar el package
echo "📱 Abriendo Xcode..."
open Gym_API.xcodeproj

echo "
🚀 INSTRUCCIONES PARA AGREGAR STREAMCHAT SDK:

1. En Xcode, ve a: File → Add Package Dependencies
2. Ingresa esta URL: https://github.com/GetStream/stream-chat-swift
3. Versión: Up to Next Major Version (5.0.0)
4. Selecciona el target: Gym_API
5. Selecciona el producto: StreamChat
6. Haz clic en Add Package

Una vez agregado el SDK, puedes cerrar este script y continuar con la app.
"

# Mantener el terminal abierto para mostrar las instrucciones
read -p "Presiona Enter cuando hayas terminado de agregar el SDK..."

echo "✅ StreamChat SDK agregado exitosamente!"
echo "�� Ahora puedes usar la funcionalidad de chat real."
