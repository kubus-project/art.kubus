#!/usr/bin/env bash
set -euo pipefail
set +x

: "${IOS_DISTRIBUTION_CERTIFICATE_BASE64:?IOS_DISTRIBUTION_CERTIFICATE_BASE64 is required}"
: "${IOS_DISTRIBUTION_CERTIFICATE_PASSWORD:?IOS_DISTRIBUTION_CERTIFICATE_PASSWORD is required}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?IOS_PROVISIONING_PROFILE_BASE64 is required}"
: "${IOS_TEAM_ID:?IOS_TEAM_ID is required}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"

[[ "$IOS_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]
[[ "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]
[ "$IOS_BUNDLE_ID" != com.example.artKubus ]
export_method="${IOS_EXPORT_METHOD:-app-store}"
case "$export_method" in ad-hoc|app-store|development|enterprise) ;; *) exit 1 ;; esac

keychain_path="$RUNNER_TEMP/art-kubus-ios-signing.keychain-db"
keychain_password="$(openssl rand -hex 32)"
certificate_path="$RUNNER_TEMP/art-kubus-distribution.p12"
profile_path="$RUNNER_TEMP/art-kubus.mobileprovision"
profile_plist="$RUNNER_TEMP/art-kubus-profile.plist"
printf '%s' "$IOS_DISTRIBUTION_CERTIFICATE_BASE64" | base64 --decode > "$certificate_path"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$profile_path"
chmod 600 "$certificate_path" "$profile_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security list-keychain -d user -s "$keychain_path"
security import "$certificate_path" -k "$keychain_path" -P "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path"
security find-identity -v -p codesigning "$keychain_path" | grep -Eq '[1-9][0-9]* valid identities'

security cms -D -i "$profile_path" > "$profile_plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$profile_plist")"
profile_team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist")"
profile_app_id="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$profile_plist")"
[ "$profile_team" = "$IOS_TEAM_ID" ]
[ "$profile_app_id" = "$IOS_TEAM_ID.$IOS_BUNDLE_ID" ]
profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profile_dir"
cp "$profile_path" "$profile_dir/$profile_uuid.mobileprovision"

{
  echo "KUBUS_IOS_BUNDLE_ID = $IOS_BUNDLE_ID"
  echo "DEVELOPMENT_TEAM = $IOS_TEAM_ID"
  echo 'CODE_SIGN_STYLE = Manual'
  echo "PROVISIONING_PROFILE_SPECIFIER = $profile_uuid"
  echo 'CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution'
} > ios/Flutter/Release-CI.xcconfig

export_options="$RUNNER_TEMP/ExportOptions.plist"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  echo '<plist version="1.0"><dict>'
  echo "<key>method</key><string>$export_method</string>"
  echo '<key>signingStyle</key><string>manual</string>'
  echo "<key>teamID</key><string>$IOS_TEAM_ID</string>"
  echo "<key>provisioningProfiles</key><dict><key>$IOS_BUNDLE_ID</key><string>$profile_uuid</string></dict>"
  echo '</dict></plist>'
} > "$export_options"

{
  echo "IOS_SIGNING_KEYCHAIN=$keychain_path"
  echo "IOS_EXPORT_OPTIONS=$export_options"
} >> "$GITHUB_ENV"
