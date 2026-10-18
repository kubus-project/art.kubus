#!/usr/bin/env bash
set -euo pipefail
set +x

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"

# Name every missing setting at once (names only, never values) so the owner
# can fix the configuration in one pass.
missing=()
for name in IOS_DISTRIBUTION_CERTIFICATE_BASE64 IOS_DISTRIBUTION_CERTIFICATE_PASSWORD IOS_PROVISIONING_PROFILE_BASE64; do
  [ -n "${!name:-}" ] || missing+=("secret $name (ios-release environment)")
done
for name in IOS_TEAM_ID IOS_BUNDLE_ID; do
  [ -n "${!name:-}" ] || missing+=("variable $name")
done
if [ "${#missing[@]}" -gt 0 ]; then
  for item in "${missing[@]}"; do echo "::error::iOS signing is not configured: missing $item"; done
  exit 1
fi

[[ "$IOS_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo '::error::IOS_TEAM_ID must be the 10-character Apple team identifier'; exit 1; }
[[ "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo '::error::IOS_BUNDLE_ID is not a reverse-DNS bundle identifier'; exit 1; }
[ "$IOS_BUNDLE_ID" != com.example.artKubus ] || { echo '::error::IOS_BUNDLE_ID is the Flutter template identifier'; exit 1; }
export_method="${IOS_EXPORT_METHOD:-app-store}"

keychain_path="$RUNNER_TEMP/art-kubus-ios-signing.keychain-db"
keychain_password="$(openssl rand -hex 32)"
echo "::add-mask::$keychain_password"
certificate_path="$RUNNER_TEMP/art-kubus-distribution.p12"
profile_path="$RUNNER_TEMP/art-kubus.mobileprovision"
profile_plist="$RUNNER_TEMP/art-kubus-profile.plist"
profile_facts="$RUNNER_TEMP/art-kubus-profile.facts"
export_options="$RUNNER_TEMP/ExportOptions.plist"

# Publish the cleanup targets first: the always-run cleanup step must find the
# keychain and decoded files even when a later command here fails.
{
  echo "IOS_SIGNING_KEYCHAIN=$keychain_path"
  echo "IOS_SIGNING_TEMP_FILES=$certificate_path $profile_path $profile_plist $profile_facts $export_options"
} >> "$GITHUB_ENV"

umask 077
printf '%s' "$IOS_DISTRIBUTION_CERTIFICATE_BASE64" | base64 --decode > "$certificate_path"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$profile_path"

security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
existing_keychains=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"; line="${line%\"}"; line="${line#\"}"
  [ -n "$line" ] && existing_keychains+=("$line")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$keychain_path" "${existing_keychains[@]}"
security import "$certificate_path" -k "$keychain_path" -P "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
rm -f "$certificate_path"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path" > /dev/null
identity_hashes="$(security find-identity -v -p codesigning "$keychain_path" | awk '$2 ~ /^[0-9A-F]{40}$/ { print $2 }' | paste -sd, -)"
[ -n "$identity_hashes" ] || { echo '::error::IOS_DISTRIBUTION_CERTIFICATE_BASE64 holds no valid code-signing identity (check the .p12 and its password)'; exit 1; }

security cms -D -i "$profile_path" > "$profile_plist"
node "$(dirname "${BASH_SOURCE[0]}")/inspect_ios_profile.mjs" \
  --profile-plist "$profile_plist" \
  --team-id "$IOS_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --export-method "$export_method" \
  --identity-hashes "$identity_hashes" \
  --output "$profile_facts"
profile_uuid="$(sed -n 's/^uuid=//p' "$profile_facts")"
# Exact common name of the certificate the profile was matched against: an
# Apple Development identity for development exports, Apple Distribution otherwise.
signing_identity="$(sed -n 's/^signing_identity=//p' "$profile_facts")"

profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
installed_profile="$profile_dir/$profile_uuid.mobileprovision"
mkdir -p "$profile_dir"
cp "$profile_path" "$installed_profile"
echo "IOS_INSTALLED_PROFILE=$installed_profile" >> "$GITHUB_ENV"

{
  echo "KUBUS_IOS_BUNDLE_ID = $IOS_BUNDLE_ID"
  echo "DEVELOPMENT_TEAM = $IOS_TEAM_ID"
  echo 'CODE_SIGN_STYLE = Manual'
  echo "PROVISIONING_PROFILE_SPECIFIER = $profile_uuid"
  echo "CODE_SIGN_IDENTITY[sdk=iphoneos*] = $signing_identity"
} > ios/Flutter/Release-CI.xcconfig

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
  echo "IOS_EXPORT_OPTIONS=$export_options"
  echo "IOS_PROFILE_UUID=$profile_uuid"
  echo "IOS_EXPORT_METHOD_RESOLVED=$export_method"
} >> "$GITHUB_ENV"
