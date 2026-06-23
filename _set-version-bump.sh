echo "🚀 Running versioning script..."

# Set the marketing version
xcrun agvtool new-marketing-version 5.0.0

# Generate build number based on date
buildNumber=$(date "+%Y%m.%d.%H%M")
echo "Generated build number: $buildNumber"

# Set the build number
xcrun agvtool new-version -all "$buildNumber"

# Optional: macOS notification
osascript -e "display notification \"Build: $buildNumber\" with title \"Versioning Script\" sound name \"Glass\""

echo "✅ Versioning complete"
