#!/bin/bash
#
# Record & prepare App Store preview video.
#
# Usage:
#   ./scripts/record-demo.sh                    # record + process
#   ./scripts/record-demo.sh --process-only     # only process existing raw recording
#
# Requirements: ffmpeg (brew install ffmpeg)
#
# Output:
#   demo_raw.mp4       — raw simulator recording
#   demo_appstore.mp4  — cropped/scaled for App Store (1290x2796, ≤30s)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RAW="$PROJECT_DIR/demo_raw.mp4"
OUTPUT="$PROJECT_DIR/demo_appstore.mp4"

SIMULATOR="iPhone 17 Pro"
# App Store 6.7" display: 1290x2796
TARGET_W=1290
TARGET_H=2796
# Seconds to trim from the beginning (simulator boot + app launch)
TRIM_START=14.5
# Speed ramp: speed up a segment (times after trimming, e.g. 10-15s of final video)
SPEED_START=6    # start of sped-up segment (seconds in trimmed video)
SPEED_END=15      # end of sped-up segment
SPEED_FACTOR=1.5  # playback speed multiplier

# ── Helpers ──────────────────────────────────────────────────────

cleanup() {
    if [[ -n "${RECORD_PID:-}" ]] && kill -0 "$RECORD_PID" 2>/dev/null; then
        kill -INT "$RECORD_PID" 2>/dev/null
        wait "$RECORD_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

check_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null; then
        echo "❌ ffmpeg not found. Install: brew install ffmpeg"
        exit 1
    fi
}

# ── Record ───────────────────────────────────────────────────────

record() {
    echo "🎬 Booting simulator: $SIMULATOR"
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    sleep 2

    echo "🔴 Starting screen recording → $RAW"
    xcrun simctl io booted recordVideo --force "$RAW" &
    RECORD_PID=$!
    sleep 1

    echo "🧪 Running demo test..."
    xcodebuild test \
        -project "$PROJECT_DIR/BibleGarden.xcodeproj" \
        -scheme BibleGarden \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -only-testing:BibleGardenUITests/DemoRecordingTests/testAppStoreDemo \
        2>&1 | grep -E '(Test Case|TEST SUCCEEDED|TEST FAILED|error:)'

    sleep 1
    echo "⏹ Stopping recording..."
    kill -INT "$RECORD_PID" 2>/dev/null
    wait "$RECORD_PID" 2>/dev/null || true
    unset RECORD_PID

    echo "✅ Raw recording: $RAW"
}

# ── Process ──────────────────────────────────────────────────────

process() {
    check_ffmpeg

    if [[ ! -f "$RAW" ]]; then
        echo "❌ Raw recording not found: $RAW"
        echo "   Run without --process-only first."
        exit 1
    fi

    # Get source dimensions
    SRC_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$RAW")
    SRC_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$RAW")
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
    DURATION_INT=${DURATION%.*}

    TRIMMED_DUR=$(echo "$DURATION - $TRIM_START" | bc)

    echo "📐 Source: ${SRC_W}x${SRC_H}, ${DURATION_INT}s"
    echo "📐 Target: ${TARGET_W}x${TARGET_H}, skip first ${TRIM_START}s"
    echo "⏩ Speed ×${SPEED_FACTOR} from ${SPEED_START}s to ${SPEED_END}s (in trimmed video)"

    # Scale + crop filter (reused in all segments)
    SCALE="scale=${TARGET_W}:-2,crop=${TARGET_W}:${TARGET_H}:(iw-${TARGET_W})/2:(ih-${TARGET_H})/2,setsar=1"

    # PTS factor: 1/speed (e.g. 1.5x → PTS*0.6667)
    PTS_FACTOR=$(echo "scale=4; 1 / $SPEED_FACTOR" | bc)

    # Absolute timestamps in raw file
    RAW_A=$TRIM_START                                        # start of part 1
    RAW_B=$(echo "$TRIM_START + $SPEED_START" | bc)          # start of sped-up part
    RAW_C=$(echo "$TRIM_START + $SPEED_END" | bc)            # start of part 3
    RAW_END=$DURATION                                        # end

    # Complex filter: 3 segments from same input, speed up the middle one
    FILTER_COMPLEX="
        [0:v]trim=start=${RAW_A}:end=${RAW_B},setpts=PTS-STARTPTS,${SCALE}[part1];
        [0:v]trim=start=${RAW_B}:end=${RAW_C},setpts=${PTS_FACTOR}*(PTS-STARTPTS),${SCALE}[part2];
        [0:v]trim=start=${RAW_C},setpts=PTS-STARTPTS,${SCALE}[part3];
        [part1][part2][part3]concat=n=3:v=1:a=0[out]
    "

    echo "🔄 Processing..."
    ffmpeg -y -i "$RAW" \
        -filter_complex "$FILTER_COMPLEX" \
        -map "[out]" \
        -c:v h264 -profile:v high -level 4.2 \
        -pix_fmt yuv420p \
        -b:v 12M -maxrate 15M -bufsize 20M \
        -an \
        "$OUTPUT" 2>&1 | grep -E '(frame=|error|Error)' || true

    # Verify output
    OUT_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$OUTPUT")
    OUT_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$OUTPUT")
    OUT_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT")
    OUT_SIZE=$(du -h "$OUTPUT" | cut -f1)

    echo ""
    echo "✅ App Store preview ready: $OUTPUT"
    echo "   Resolution: ${OUT_W}x${OUT_H}"
    echo "   Duration:   ${OUT_DUR%.*}s"
    echo "   Size:       $OUT_SIZE"
}

# ── Main ─────────────────────────────────────────────────────────

if [[ "${1:-}" == "--process-only" ]]; then
    process
else
    record
    process
fi
