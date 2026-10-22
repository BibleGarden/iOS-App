#!/usr/bin/env bash
# Boots the CI simulator SIMULATOR_NAME with iOS SIMULATOR_OS and exports its
# UDID as SIMULATOR_ID for later steps.
# On a fresh runner CoreSimulator may still be loading its runtimes, and
# xcodebuild then sees no simulators at all. The wait is bounded and fails
# with the runtime list instead of letting xcodebuild guess.
set -euo pipefail

timeout=300
runtime="com.apple.CoreSimulator.SimRuntime.iOS-${SIMULATOR_OS//./-}"
deadline=$((SECONDS + timeout))

until udid=$(xcrun simctl list devices available --json \
  | jq -er --arg runtime "$runtime" --arg name "$SIMULATOR_NAME" \
      '[.devices[$runtime][]? | select(.name == $name) | .udid][0] // empty'); do
  if (( SECONDS >= deadline )); then
    echo "::error title=Simulator unavailable::No available $SIMULATOR_NAME with iOS $SIMULATOR_OS after ${timeout}s."
    xcrun simctl list runtimes
    exit 1
  fi
  sleep 10
done

echo "Booting $SIMULATOR_NAME (iOS $SIMULATOR_OS) $udid after $SECONDS s"
xcrun simctl bootstatus "$udid" -b
echo "SIMULATOR_ID=$udid" >> "$GITHUB_ENV"
