#!/bin/bash
# Sign the unsigned entry HAP with the debug signing material.
set -euo pipefail

PROJECT_DIR="/workspace"
SIGN_DIR="${PROJECT_DIR}/signature"
SDK_LIB="/opt/ohos-sdk/12/toolchains/lib"
OUTPUT_DIR="${PROJECT_DIR}/entry/build/default/outputs/default"

UNSIGNED_HAP="${OUTPUT_DIR}/entry-default-unsigned.hap"
SIGNED_HAP="${OUTPUT_DIR}/entry-default-signed.hap"
PASS="123456"

if [ ! -f "${UNSIGNED_HAP}" ]; then
    echo "Unsigned HAP not found: ${UNSIGNED_HAP}" >&2
    echo "Run the build first." >&2
    exit 1
fi

java -jar "${SDK_LIB}/hap-sign-tool.jar" sign-app \
    -mode localSign \
    -keyAlias "fullkeyboard-key" \
    -keyPwd "${PASS}" \
    -appCertFile "${SIGN_DIR}/FullKeyboard_app.pem" \
    -profileFile "${SIGN_DIR}/FullKeyboardDebug.p7b" \
    -inFile "${UNSIGNED_HAP}" \
    -signAlg SHA256withECDSA \
    -keystoreFile "${SIGN_DIR}/FullKeyboard.p12" \
    -keystorePwd "${PASS}" \
    -outFile "${SIGNED_HAP}" \
    -compatibleVersion 12 \
    -signCode 1

echo "Signed HAP: ${SIGNED_HAP}"
