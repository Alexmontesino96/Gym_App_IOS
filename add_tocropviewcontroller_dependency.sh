#!/bin/bash

# Script para agregar TOCropViewController al proyecto Xcode via SPM
# Uso: ./add_tocropviewcontroller_dependency.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_FILE="$SCRIPT_DIR/Gym_API.xcodeproj/project.pbxproj"

echo "🔍 Verificando proyecto Xcode..."
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: No se encontró project.pbxproj"
    exit 1
fi

echo "📦 Agregando TOCropViewController como dependencia SPM..."

# URL del repositorio
PACKAGE_URL="https://github.com/TimOliver/TOCropViewController.git"
PACKAGE_NAME="TOCropViewController"

# Verificar si ya existe la dependencia
if grep -q "TOCropViewController" "$PROJECT_FILE"; then
    echo "⚠️  TOCropViewController ya está agregado al proyecto"
    echo "✅ No se requiere acción"
    exit 0
fi

echo "➕ Agregando $PACKAGE_NAME al proyecto..."
echo ""
echo "⚠️  NOTA: Este script requiere modificación manual del proyecto."
echo ""
echo "Por favor, agrega TOCropViewController manualmente en Xcode:"
echo ""
echo "1. Abre el proyecto: Gym_API.xcodeproj"
echo "2. Selecciona el proyecto en el navegador"
echo "3. Ve a la pestaña 'Package Dependencies'"
echo "4. Click en el botón '+'"
echo "5. Pega esta URL: $PACKAGE_URL"
echo "6. Selecciona 'Up to Next Major Version' con versión mínima 2.0.0"
echo "7. Click 'Add Package'"
echo "8. Asegúrate de que CropViewController esté marcado para el target Gym_API"
echo ""
echo "Nota: TOCropViewController tiene 2 módulos:"
echo "  - CropViewController (Swift wrapper - recomendado)"
echo "  - TOCropViewController (Objective-C original)"
echo ""
echo "Para este proyecto usa el módulo Swift: CropViewController"
echo ""
echo "📝 Para verificar la instalación después de agregar en Xcode:"
echo "   cd Gym_API"
echo "   xcodebuild -resolvePackageDependencies"
echo ""
echo "✅ Script completado"
