#!/bin/sh

# Prepares an Xcode Cloud runner for this Flutter app.
#
# Xcode Cloud clones the repository and then builds the Xcode project directly.
# It knows nothing about Flutter, so without this script the build fails on the
# first line of ios/Flutter/Generated.xcconfig, which is not in the repository
# because it is generated per machine and holds absolute paths.
#
# Xcode Cloud runs this after cloning and before resolving dependencies, from
# inside ci_scripts/, with CI_PRIMARY_REPOSITORY_PATH pointing at the checkout.
#
# There is no Podfile in this project, so nothing installs CocoaPods here. Add
# a pod install step if that ever changes.

set -e

# Keep this in step with the SDK the app is developed against. Xcode Cloud has
# no Flutter of its own, so an unpinned clone would silently move the build to
# whatever stable happens to be current that day.
FLUTTER_VERSION="3.47.0"
FLUTTER_HOME="$HOME/flutter"

echo "Installing Flutter $FLUTTER_VERSION"
git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_HOME"
export PATH="$FLUTTER_HOME/bin:$PATH"

# The runner is thrown away after the build, so opting out of analytics is
# about not reporting a machine that does not exist rather than about privacy.
flutter config --no-analytics
flutter --version

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Fetching packages"
flutter pub get

echo "Precaching the iOS artifacts"
flutter precache --ios

# Writes ios/Flutter/Generated.xcconfig, which carries FLUTTER_ROOT, the build
# name and the build number from pubspec.yaml. pubspec.yaml stays the single
# source of the version; Xcode Cloud's own CI_BUILD_NUMBER is deliberately not
# used, so a cloud build and a local one produce the same number.
echo "Writing the Flutter build configuration"
flutter build ios --config-only --release

echo "Ready for the Xcode build"
