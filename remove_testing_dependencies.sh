#!/bin/bash

echo "🔧 Corrigiendo dependencias de testing en el proyecto..."

PROJECT_PATH="Gym_API.xcodeproj"

# Verificar que el proyecto existe
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ No se encontró el proyecto en $PROJECT_PATH"
    exit 1
fi

echo "📋 Instrucciones para remover dependencias de testing en Xcode:"
echo ""
echo "1. Abrir el proyecto en Xcode:"
echo "   open $PROJECT_PATH"
echo ""
echo "2. Seleccionar el target 'Gym_API' en el panel izquierdo"
echo ""
echo "3. Ir a la pestaña 'General'"
echo ""
echo "4. En la sección 'Frameworks, Libraries, and Embedded Content':"
echo "   - Seleccionar 'StreamChatTestTools'"
echo "   - Hacer clic en el botón '-' para removerla"
echo "   - Seleccionar 'StreamChatTestMockServer'"
echo "   - Hacer clic en el botón '-' para removerla"
echo ""
echo "5. Compilar el proyecto de nuevo. Los errores de 'XCTest' deberían desaparecer."
echo ""
echo "✅ Una vez removidas estas dependencias, el proyecto debería compilar sin errores." 