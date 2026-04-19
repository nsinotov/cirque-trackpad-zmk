#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Cirque Trackpad — local ZMK build script (Docker)
#
# Usage:
#   ./build.sh            — build firmware
#   ./build.sh reset      — build settings_reset firmware
#   ./build.sh --flash    — build + copy .uf2 to mounted bootloader drive
#   ./build.sh --help
#
# Prerequisites: Docker
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DOCKER_IMAGE="zmkfirmware/zmk-build-arm:stable"
FIRMWARE_DIR="firmware"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

BOARD="nice_nano//zmk"
SHIELD="cirque_trackpad"

# ── macOS: bootloader drive name (double-tap RST to enter DFU) ───────────────
BOOTLOADER_VOLUME="/Volumes/NICENANO"

# ─────────────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [reset] [--flash] [--help]"
    echo ""
    echo "  (no args)   build cirque_trackpad firmware"
    echo "  reset       build settings_reset firmware"
    echo "  --flash     build + copy .uf2 to $BOOTLOADER_VOLUME"
    echo "  --help      this message"
}

TARGET="cirque_trackpad"
FLASH=0

for arg in "$@"; do
    case "$arg" in
        reset)   TARGET="reset" ;;
        --flash) FLASH=1 ;;
        --help)  usage; exit 0 ;;
        *) echo "Unknown argument: $arg"; usage; exit 1 ;;
    esac
done

# ── sanity checks ─────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "ERROR: 'docker' not found. Install Docker Desktop."
    exit 1
fi

mkdir -p "$FIRMWARE_DIR"

# ── build ─────────────────────────────────────────────────────────────────────
build_target() {
    local name="$1"
    local board="$2"
    local shield="$3"
    local snippet="${4:-}"

    local snippet_flag=""
    if [[ -n "$snippet" ]]; then
        snippet_flag="-S $snippet"
    fi

    echo "==> Building $name ($board / $shield${snippet:+ / snippet: $snippet})"

    docker run --rm \
        -v "$REPO_DIR:/repo:ro" \
        -v "$REPO_DIR/$FIRMWARE_DIR:/output" \
        -e "BUILD_BOARD=$board" \
        -e "BUILD_SHIELD=$shield" \
        -e "BUILD_SNIPPET=$snippet_flag" \
        -e "BUILD_NAME=$name" \
        "$DOCKER_IMAGE" \
        sh -c '
            set -e
            cp -r /repo /workspace && rm -rf /workspace/.west && cd /workspace
            west init -l config/
            west update
            west zephyr-export
            west build -s zmk/app -b "$BUILD_BOARD" $BUILD_SNIPPET -p -- -DSHIELD="$BUILD_SHIELD" -DZMK_CONFIG=/workspace/config
            cp build/zephyr/zmk.uf2 /output/"$BUILD_NAME".uf2
        '

    echo "==> $name.uf2 ready"
}

case "$TARGET" in
    cirque_trackpad)
        build_target "cirque_trackpad" "$BOARD" "$SHIELD" "zmk-usb-logging"
        ;;
    reset)
        build_target "settings_reset" "$BOARD" "settings_reset"
        ;;
esac

echo ""
echo "Firmware files in $FIRMWARE_DIR/:"
ls -la "$FIRMWARE_DIR/"*.uf2 2>/dev/null || echo "  (none)"

# ── flash ─────────────────────────────────────────────────────────────────────
if [[ $FLASH -eq 1 ]]; then
    if [[ "$TARGET" == "reset" ]]; then
        UF2_FILE="$FIRMWARE_DIR/settings_reset.uf2"
    else
        UF2_FILE="$FIRMWARE_DIR/cirque_trackpad.uf2"
    fi

    echo ""
    echo "── Flash: waiting for $BOOTLOADER_VOLUME ──"
    echo "Double-tap RST on the controller now…"

    TIMEOUT=30
    ELAPSED=0
    until [[ -d "$BOOTLOADER_VOLUME" ]]; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "ERROR: $BOOTLOADER_VOLUME did not appear within ${TIMEOUT}s."
            echo "Check that the controller is in bootloader mode."
            exit 1
        fi
    done

    echo "Drive found — copying .uf2…"
    cp "$UF2_FILE" "$BOOTLOADER_VOLUME/"
    echo "Done. Controller will reboot automatically."
fi
