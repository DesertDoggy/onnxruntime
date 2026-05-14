#!/usr/bin/env bash
# Build ONNX Runtime as a static library (macOS and Linux).
#
# Usage:
#   ./scripts/build_static.sh [--config <Debug|Release|RelWithDebInfo>]
#                             [--build_dir <path>]
#                             [--parallel [N]]
#                             [-- <extra build.py flags>]
#
# Defaults:
#   --config    Release
#   --build_dir build/<OS>   (e.g. build/MacOS or build/Linux)
#
# All flags after '--' are forwarded verbatim to tools/ci_build/build.py.
#
# Example (RelWithDebInfo, custom output dir):
#   ./scripts/build_static.sh --config RelWithDebInfo --build_dir /tmp/ort_build

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# ---------- defaults ----------
CONFIG="Release"
BUILD_DIR=""
PARALLEL_JOBS=""   # empty = use all cores
EXTRA_ARGS=()

# ---------- parse arguments ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG="$2"; shift 2 ;;
        --build_dir)
            BUILD_DIR="$2"; shift 2 ;;
        --parallel)
            # optional value: --parallel or --parallel N
            if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                PARALLEL_JOBS="$2"; shift 2
            else
                PARALLEL_JOBS="0"; shift 1
            fi
            ;;
        --)
            shift; EXTRA_ARGS=("$@"); break ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -- to pass extra flags to build.py" >&2
            exit 1 ;;
    esac
done

# ---------- resolve defaults ----------
OS="$(uname -s)"
if [[ -z "$BUILD_DIR" ]]; then
    case "$OS" in
        Darwin) BUILD_DIR="$ROOT_DIR/build/MacOS" ;;
        *)      BUILD_DIR="$ROOT_DIR/build/Linux"  ;;
    esac
fi

# ---------- parallel flag ----------
if [[ -n "$PARALLEL_JOBS" ]]; then
    PARALLEL_FLAG=("--parallel" "$PARALLEL_JOBS")
else
    PARALLEL_FLAG=("--parallel")
fi

# ---------- locate Python ----------
PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" &>/dev/null; then
    echo "ERROR: python3 not found. Set PYTHON= env var or add python3 to PATH." >&2
    exit 1
fi

echo "===================================================================="
echo "  Building ONNX Runtime as a static library"
echo "  OS         : $OS"
echo "  Config     : $CONFIG"
echo "  Build dir  : $BUILD_DIR"
echo "  Extra args : ${EXTRA_ARGS[*]:-<none>}"
echo "===================================================================="

# ---------- work around Homebrew protobuf version conflict ----------
# ORT bundles protobuf 21.12. If a newer Homebrew protobuf (v22+) is linked,
# the bundled .pb.h files (which use the old PROTOBUF_NAMESPACE_* macros) fail
# to compile. Temporarily unlink it if present, then restore on exit.
BREW_PROTOBUF_UNLINKED=0
if command -v brew &>/dev/null; then
    if brew list --versions protobuf &>/dev/null; then
        PB_VERSION="$(brew list --versions protobuf | awk '{print $2}')"
        PB_MAJOR="${PB_VERSION%%.*}"
        if [[ "$PB_MAJOR" -ge 22 ]]; then
            echo "  [info] Temporarily unlinking Homebrew protobuf $PB_VERSION to avoid version conflict..."
            brew unlink protobuf
            BREW_PROTOBUF_UNLINKED=1
        fi
    fi
fi
# Ensure we always re-link protobuf on exit, even if the build fails.
trap '[[ "$BREW_PROTOBUF_UNLINKED" -eq 1 ]] && brew link protobuf' EXIT

"$PYTHON" "$ROOT_DIR/tools/ci_build/build.py" \
    --build_dir "$BUILD_DIR" \
    --config "$CONFIG" \
    --cmake_generator "Unix Makefiles" \
    --update \
    --build \
    --skip_tests \
    "${PARALLEL_FLAG[@]}" \
    --cmake_extra_defines \
        CMAKE_POSITION_INDEPENDENT_CODE=ON \
        onnxruntime_BUILD_UNIT_TESTS=OFF \
    "${EXTRA_ARGS[@]}"

echo ""
echo "===================================================================="
echo "  Build complete."
echo "  Static libraries are in: $BUILD_DIR/$CONFIG/"
echo "  Key artifacts:"
echo "    libonnxruntime.a (or onnxruntime.lib on MSVC)"
echo "    libonnxruntime_common.a"
echo "  Public headers: $ROOT_DIR/include/onnxruntime/"
echo "===================================================================="
