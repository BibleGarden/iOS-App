#!/usr/bin/env bash
# Writes BibleGarden/Debug.xcconfig for CI from API_BASE_URL and API_KEY.
# The app reads it at build time; UI tests read the same file at run time
# through TestConfig (#filePath of the build machine), so every CI job that
# builds or runs the tests needs it at the checkout path.
set -euo pipefail

if [ -z "${API_BASE_URL:-}" ] || [ -z "${API_KEY:-}" ]; then
  echo "::error::API_BASE_URL and repository secret API_KEY must be set."
  exit 1
fi

# xcconfig treats // as a comment; $() breaks the sequence.
{
  echo "API_BASE_URL = ${API_BASE_URL/:\/\//:/\$()/}"
  echo "API_KEY = $API_KEY"
} > "$(dirname "$0")/../BibleGarden/Debug.xcconfig"
