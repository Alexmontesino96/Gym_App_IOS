#!/bin/bash

# Script to add Stripe SDK to Xcode project via Swift Package Manager
echo "🔧 Adding Stripe SDK to Gym_API project..."

# Project path
PROJECT_PATH="Gym_API.xcodeproj/project.pbxproj"

# Check if project file exists
if [ ! -f "$PROJECT_PATH" ]; then
    echo "❌ Project file not found at $PROJECT_PATH"
    exit 1
fi

# Create backup
cp "$PROJECT_PATH" "${PROJECT_PATH}.backup_stripe"
echo "✅ Backup created: ${PROJECT_PATH}.backup_stripe"

# Add Stripe package dependency
# Note: This requires manual intervention in Xcode for proper integration
echo "⚠️ Manual steps required:"
echo ""
echo "1. Open Gym_API.xcodeproj in Xcode"
echo "2. Go to File > Add Package Dependencies..."
echo "3. Enter URL: https://github.com/stripe/stripe-ios"
echo "4. Select version: Up to Next Major Version (28.0.0)"
echo "5. Add these products to your target:"
echo "   - StripePaymentSheet"
echo "   - StripeCore"
echo ""
echo "📦 Stripe SDK URL: https://github.com/stripe/stripe-ios"
echo "📌 Recommended version: 28.0.0 or latest"
echo ""
echo "After adding the package in Xcode, the integration will be complete."
echo ""
echo "🔑 Don't forget to configure your Stripe publishable key in the app!"

# Alternative: Create a Package.resolved entry (for reference)
cat << 'EOF' > stripe_package_reference.json
{
  "package": "Stripe",
  "repositoryURL": "https://github.com/stripe/stripe-ios",
  "version": "28.0.0",
  "products": [
    "StripePaymentSheet",
    "StripeCore"
  ]
}
EOF

echo "📄 Reference file created: stripe_package_reference.json"
echo "✅ Script completed. Please follow the manual steps in Xcode."