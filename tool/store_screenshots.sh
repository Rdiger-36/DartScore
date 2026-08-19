#!/usr/bin/env bash
#
# Renders every raw store screenshot, one run per device and language.
#
# Each run drives integration_test/store_screenshots_test.dart on a booted
# simulator or emulator and shoots three screens in both themes, so the eight
# runs fill store_assets/screenshots/raw/<device>/<theme>/<language>/.
#
# Usage:
#   tool/store_screenshots.sh                  # every device
#   tool/store_screenshots.sh iphone ipad      # only the named ones
#
# The devices are picked to match what the two stores ask for:
#   iphone         iPhone 17 Pro Max, 1320x2868, the App Store 6.9" slot
#   ipad           iPad Pro 13", 2064x2752, the App Store 13" slot
#   android_phone  1080x2400, cropped to 1080x2160 by the composer, because
#                  Google Play rejects a side more than twice the other
#   android_tablet Pixel Tablet, 2560x1600, the Play 10" slot
#
# Composing the store images from what this writes is a second step:
#   dart run tool/compose_store_screenshots.dart

set -euo pipefail

cd "$(dirname "$0")/.."

LANGUAGES=(de en)

# name:kind:target, where the target is a simulator name or an AVD name.
DEVICES=(
  "iphone:ios:iPhone 17 Pro Max"
  "ipad:ios:iPad Pro 13-inch (M5)"
  "android_phone:android:Test_Android"
  "android_tablet:android:Test_Android_Tablet"
)

ADB=${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}
EMULATOR=${EMULATOR:-$(command -v emulator || echo "$HOME/Library/Android/sdk/emulator/emulator")}

# ── iOS ──────────────────────────────────────────────────────────────────────

# Prints the UDID of the newest available simulator called $1.
#
# The last match wins, which is the newest runtime: `simctl` lists the runtimes
# in ascending order.
simulator_udid() {
  xcrun simctl list devices available \
    | grep -F "    $1 (" \
    | tail -1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
}

# Boots the simulator $1 and freezes its status bar on the App Store's 9:41.
boot_simulator() {
  local udid=$1
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
}

# ── Android ──────────────────────────────────────────────────────────────────

# Boots the AVD $1 and waits until it is usable, then prints its adb id.
boot_emulator() {
  local avd=$1
  local id
  id=$("$ADB" devices | awk '/^emulator-/ { print $1; exit }')
  if [ -z "$id" ]; then
    "$EMULATOR" -avd "$avd" -no-snapshot-save -no-boot-anim >/dev/null 2>&1 &
    "$ADB" wait-for-device
    id=$("$ADB" devices | awk '/^emulator-/ { print $1; exit }')
  fi
  until [ "$("$ADB" -s "$id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 2
  done
  # Nothing is done to the status bar here: the test puts Android into
  # immersive mode, so neither bar is in the picture, which is also how the iOS
  # screenshot comes out.
  echo "$id"
}

# Shuts every running emulator down, so the next AVD is the only one attached.
stop_emulators() {
  for id in $("$ADB" devices | awk '/^emulator-/ { print $1 }'); do
    "$ADB" -s "$id" emu kill >/dev/null 2>&1 || true
  done
  sleep 3
}

# ── Runs ─────────────────────────────────────────────────────────────────────

wanted=" $* "

for entry in "${DEVICES[@]}"; do
  name=${entry%%:*}
  rest=${entry#*:}
  kind=${rest%%:*}
  target=${rest#*:}

  if [ $# -gt 0 ] && [[ "$wanted" != *" $name "* ]]; then
    continue
  fi

  if [ "$kind" = "ios" ]; then
    udid=$(simulator_udid "$target")
    if [ -z "$udid" ]; then
      echo "No simulator called '$target'. Create it in Xcode, or edit DEVICES." >&2
      exit 1
    fi
    boot_simulator "$udid"
    device_id=$udid
  else
    stop_emulators
    device_id=$(boot_emulator "$target")
  fi

  for lang in "${LANGUAGES[@]}"; do
    echo "── $name / $lang ──"
    flutter drive \
      --driver test_driver/store_screenshots_driver.dart \
      --target integration_test/store_screenshots_test.dart \
      -d "$device_id" \
      --dart-define=device="$name" \
      --dart-define=lang="$lang"
  done
done

echo
echo "Raw screenshots are in store_assets/screenshots/raw/."
echo "Compose the store images with: dart run tool/compose_store_screenshots.dart"
