#!/bin/bash
#
# Record & prepare App Store preview videos (supports multiple languages).
#
# Usage:
#   ./scripts/record-demo.sh                    # record + process all 3 languages
#   ./scripts/record-demo.sh --lang ru          # record + process single language
#   ./scripts/record-demo.sh --process-only     # process all existing raw recordings
#   ./scripts/record-demo.sh --process-only --lang en  # process single language
#
# Requirements: ffmpeg (brew install ffmpeg)
#
# Output (in demo_videos/ folder):
#   demo_raw_{lang}.mp4       — raw simulator recording
#   demo_appstore_{lang}.mp4  — cropped/scaled for App Store (1290x2796)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VIDEO_DIR="$PROJECT_DIR/demo_videos"
mkdir -p "$VIDEO_DIR"

SIMULATOR="iPhone 16 Pro Max"
# App Store preview 6.5"/6.7" display: 886x1920 (portrait)
TARGET_W=886
TARGET_H=1920
# Seconds to trim from the beginning (simulator boot + app launch)
TRIM_START=12.5
# Speed ramp: speed up a segment (times after trimming, e.g. 6-15s of final video)
SPEED_START=6     # start of sped-up segment (seconds in trimmed video)
SPEED_END=15      # end of sped-up segment
SPEED_FACTOR=1.5  # playback speed multiplier
# Seconds to trim from the end
TRIM_END=1

ALL_LANGUAGES=("ru" "en" "uk")
LANGUAGES=("${ALL_LANGUAGES[@]}")
PROCESS_ONLY=false

# ── Parse args ───────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)
            LANGUAGES=("$2")
            shift 2
            ;;
        --process-only)
            PROCESS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown arg: $1"
            exit 1
            ;;
    esac
done

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
    local LANG_CODE="$1"
    local RAW="$VIDEO_DIR/demo_raw_${LANG_CODE}.mp4"

    echo ""
    echo "🎬 [$LANG_CODE] Booting simulator: $SIMULATOR"
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    sleep 2

    echo "🔴 [$LANG_CODE] Starting screen recording → $RAW"
    xcrun simctl io booted recordVideo --force "$RAW" &
    RECORD_PID=$!
    sleep 1

    echo "🧪 [$LANG_CODE] Running demo test..."
    echo "$LANG_CODE" > /tmp/biblegarden_demo_lang
    xcodebuild test \
        -project "$PROJECT_DIR/BibleGarden.xcodeproj" \
        -scheme BibleGarden \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -only-testing:BibleGardenUITests/DemoRecordingTests/testAppStoreDemo \
        2>&1 | grep -E '(Test Case|TEST SUCCEEDED|TEST FAILED|error:)'

    sleep 1
    echo "⏹ [$LANG_CODE] Stopping recording..."
    kill -INT "$RECORD_PID" 2>/dev/null
    wait "$RECORD_PID" 2>/dev/null || true
    unset RECORD_PID

    echo "✅ [$LANG_CODE] Raw recording: $RAW"
}

# ── Process ──────────────────────────────────────────────────────

process() {
    local LANG_CODE="$1"
    local RAW="$VIDEO_DIR/demo_raw_${LANG_CODE}.mp4"
    local OUTPUT="$VIDEO_DIR/demo_appstore_${LANG_CODE}.mp4"

    check_ffmpeg

    if [[ ! -f "$RAW" ]]; then
        echo "❌ [$LANG_CODE] Raw recording not found: $RAW"
        echo "   Run without --process-only first."
        return 1
    fi

    # Get source dimensions
    SRC_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$RAW")
    SRC_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$RAW")
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")
    DURATION_INT=${DURATION%.*}

    echo ""
    echo "📐 [$LANG_CODE] Source: ${SRC_W}x${SRC_H}, ${DURATION_INT}s"
    USABLE_DUR=$(echo "$DURATION - $TRIM_START - $TRIM_END" | bc)
    echo "📐 [$LANG_CODE] Target: ${TARGET_W}x${TARGET_H}, trim ${TRIM_START}s start + ${TRIM_END}s end"
    echo "⏩ [$LANG_CODE] Speed ×${SPEED_FACTOR} from ${SPEED_START}s to ${SPEED_END}s"

    # Scale + crop filter
    SCALE="scale=${TARGET_W}:-2,crop=${TARGET_W}:${TARGET_H}:(iw-${TARGET_W})/2:(ih-${TARGET_H})/2,setsar=1"

    # PTS factor: 1/speed (e.g. 1.5x → PTS*0.6667)
    PTS_FACTOR=$(echo "scale=4; 1 / $SPEED_FACTOR" | bc)

    # After -ss trim, timestamps start from 0
    # Split into 3 segments: [0..SPEED_START] normal, [SPEED_START..SPEED_END] fast, [SPEED_END..end] normal
    FILTER_COMPLEX="
        [0:v]trim=start=0:end=${SPEED_START},setpts=PTS-STARTPTS,${SCALE}[part1];
        [0:v]trim=start=${SPEED_START}:end=${SPEED_END},setpts=${PTS_FACTOR}*(PTS-STARTPTS),${SCALE}[part2];
        [0:v]trim=start=${SPEED_END},setpts=PTS-STARTPTS,${SCALE}[part3];
        [part1][part2][part3]concat=n=3:v=1:a=0,fps=30[out]
    "

    echo "🔄 [$LANG_CODE] Processing..."
    # Check if raw file has audio
    HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$RAW" | head -1)

    if [[ "$HAS_AUDIO" == "audio" ]]; then
        # Use real audio from recording, apply same trim
        AUDIO_FILTER="[0:a]atrim=start=0,asetpts=PTS-STARTPTS[aout]"
        FULL_FILTER="${FILTER_COMPLEX%\[out\]*}[out];${AUDIO_FILTER}"

        ffmpeg -y -ss "$TRIM_START" -t "$USABLE_DUR" -i "$RAW" \
            -filter_complex "$FULL_FILTER" \
            -map "[out]" -map "[aout]" \
            -c:v h264 -profile:v high -level 4.2 \
            -pix_fmt yuv420p \
            -b:v 12M -maxrate 15M -bufsize 20M \
            -c:a aac -b:a 128k \
            "$OUTPUT" 2>&1 | grep -E '(frame=|error|Error)' || true
    else
        # No audio in raw — add silent track
        ffmpeg -y -ss "$TRIM_START" -t "$USABLE_DUR" -i "$RAW" \
            -f lavfi -i anullsrc=r=44100:cl=stereo \
            -filter_complex "$FILTER_COMPLEX" \
            -map "[out]" -map 1:a -shortest \
            -c:v h264 -profile:v high -level 4.2 \
            -pix_fmt yuv420p \
            -b:v 12M -maxrate 15M -bufsize 20M \
            -c:a aac -b:a 128k \
            "$OUTPUT" 2>&1 | grep -E '(frame=|error|Error)' || true
    fi

    # Verify output (use stream duration for accuracy, fallback to format)
    OUT_W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$OUTPUT")
    OUT_H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$OUTPUT")
    OUT_DUR=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of csv=p=0 "$OUTPUT")
    if [[ -z "$OUT_DUR" || "$OUT_DUR" == "N/A" ]]; then
        OUT_DUR=$(ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames,r_frame_rate -of csv=p=0 "$OUTPUT" | awk -F',' '{split($2,a,"/"); if(a[2]>0) printf "%.1f", $1/(a[1]/a[2])}')
    fi
    OUT_SIZE=$(du -h "$OUTPUT" | cut -f1)

    echo ""
    echo "✅ [$LANG_CODE] App Store preview ready: $OUTPUT"
    echo "   Resolution: ${OUT_W}x${OUT_H}"
    echo "   Duration:   ${OUT_DUR%.*}s"
    echo "   Size:       $OUT_SIZE"
}

# ── Main ─────────────────────────────────────────────────────────

for lang in "${LANGUAGES[@]}"; do
    echo ""
    echo "════════════════════════════════════════════════════"
    echo "  Language: $lang"
    echo "════════════════════════════════════════════════════"

    if [[ "$PROCESS_ONLY" == false ]]; then
        record "$lang"
    fi
    process "$lang"
done

echo ""
echo "🎉 Done! Processed ${#LANGUAGES[@]} language(s): ${LANGUAGES[*]}"
