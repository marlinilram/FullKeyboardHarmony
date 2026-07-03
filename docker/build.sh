#!/bin/bash
# Build FullKeyboardHarmony inside a Docker container.
# Run this script from the repository root (parent of FullKeyboardHarmony).

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${PROJECT_DIR}/.." && pwd)

IMAGE_NAME="fullkeyboard-harmony-builder"

echo "[build] Building Docker image ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}"

echo "[build] Building HAP in container..."
docker run --rm \
    -v "${PROJECT_DIR}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}"

if [ -f "${PROJECT_DIR}/signature/FullKeyboard_app.pem" ]; then
    echo "[build] Signing HAP in container..."
    docker run --rm \
        -v "${PROJECT_DIR}:/workspace" \
        -w /workspace \
        "${IMAGE_NAME}" \
        bash docker/sign-hap.sh
fi

echo "[build] Done. Output should be under ${PROJECT_DIR}/entry/build/default/outputs/default/"
