#!/bin/bash
set -uo pipefail

#############################################
# Live restream to YouTube (video URL only)
#
# Env:
#   VIDEO_URL           required (YouTube/X live URL, .m3u8, or a page yt-dlp supports)
#   YOUTUBE_STREAM_KEY  required
# Needs: ffmpeg, ffprobe, yt-dlp, overlay.png in the current dir
#############################################

[ -z "${VIDEO_URL:-}" ] && { echo "ERROR: VIDEO_URL is not set"; exit 1; }
[ -z "${YOUTUBE_STREAM_KEY:-}" ] && { echo "ERROR: YOUTUBE_STREAM_KEY is not set"; exit 1; }
[ ! -f overlay.png ] && { echo "ERROR: overlay.png not found in $(pwd)"; exit 1; }

RETRY_DELAY=5
RTMP="rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_STREAM_KEY}"

# Resolve the real media URL (falls back to the original if yt-dlp can't)
resolve_url() {
    local u
    u=$(yt-dlp -g -f "best[height<=720]/best" "$VIDEO_URL" 2>/dev/null | head -n1)
    echo "${u:-$VIDEO_URL}"
}

# Does the source have an audio track?
has_audio() {
    [ -n "$(ffprobe -v error -select_streams a -show_entries stream=index \
            -of csv=p=0 "$1" 2>/dev/null | head -n1)" ]
}

FILTER="[0:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black[v];"
FILTER+="[1:v]scale=1280:720:flags=fast_bilinear[ovl];"
FILTER+="[v][ovl]overlay=0:0:shortest=1[final]"

OUT_OPTS=(
    -r 30 -c:v libx264 -preset veryfast -tune zerolatency
    -profile:v high -level 4.1 -pix_fmt yuv420p
    -b:v 3000k -maxrate 3000k -bufsize 6000k
    -g 60 -keyint_min 60 -sc_threshold 0
    -c:a aac -b:a 128k -ar 48000 -ac 2
    -shortest -f flv
)

while true; do
    echo "Resolving stream..."
    SRC="$(resolve_url)"
    echo "Source: $SRC"

    INPUTS=(
        -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 -i "$SRC"
        -loop 1 -framerate 30 -i overlay.png
    )

    if has_audio "$SRC"; then
        echo "Using the stream's own audio."
        MAPS=(-map "[final]" -map 0:a:0)
    else
        echo "No audio track found - adding silent audio."
        INPUTS+=(-re -f lavfi -i "anullsrc=r=48000:cl=stereo")
        MAPS=(-map "[final]" -map 2:a:0)
    fi

    ffmpeg -hide_banner -loglevel info -nostdin \
        "${INPUTS[@]}" \
        -filter_complex "$FILTER" \
        "${MAPS[@]}" \
        "${OUT_OPTS[@]}" "$RTMP"
    rc=$?

    echo "WARNING: ffmpeg exited (code $rc). Restarting in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
done
