#!/bin/bash
# Generate a debug signing profile inside the container using the OpenHarmony
# public SDK debug signing material. The produced files are written to
# <project>/signature/.
set -euo pipefail

PROJECT_DIR="/workspace"
SIGN_DIR="${PROJECT_DIR}/signature"
SDK_LIB="/opt/ohos-sdk/12/toolchains/lib"
SDK_P12="${SDK_LIB}/OpenHarmony.p12"
PROFILE_PEM="${SDK_LIB}/OpenHarmonyProfileDebug.pem"
APP_KEY_ALIAS="fullkeyboard-key"
APP_KEYSTORE="${SIGN_DIR}/FullKeyboard.p12"
PASS="123456"

mkdir -p "${SIGN_DIR}"

# 1. Copy the SDK keystore and profile certificate.
cp "${SDK_P12}" "${SIGN_DIR}/OpenHarmony.p12"
cp "${PROFILE_PEM}" "${SIGN_DIR}/OpenHarmonyProfileDebug.pem"

# 2. Export the CA certificates from the SDK keystore.
keytool -exportcert -rfc \
    -alias "openharmony application ca" \
    -keystore "${SIGN_DIR}/OpenHarmony.p12" -storepass "${PASS}" \
    -file "${SIGN_DIR}/subCA.cer"
keytool -exportcert -rfc \
    -alias "openharmony application root ca" \
    -keystore "${SIGN_DIR}/OpenHarmony.p12" -storepass "${PASS}" \
    -file "${SIGN_DIR}/rootCA.cer"

# 3. Generate a new application keypair in a dedicated keystore.
java -jar "${SDK_LIB}/hap-sign-tool.jar" generate-keypair \
    -keyAlias "${APP_KEY_ALIAS}" \
    -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile "${APP_KEYSTORE}" \
    -keyPwd "${PASS}" -keystorePwd "${PASS}"

# 4. Generate the application signing certificate chain.
java -jar "${SDK_LIB}/hap-sign-tool.jar" generate-app-cert \
    -keyAlias "${APP_KEY_ALIAS}" -keyPwd "${PASS}" \
    -signAlg SHA256withECDSA \
    -issuer "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA" \
    -issuerKeyAlias "openharmony application ca" -issuerKeyPwd "${PASS}" \
    -issuerKeystoreFile "${SIGN_DIR}/OpenHarmony.p12" -issuerKeystorePwd "${PASS}" \
    -subject "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=FullKeyboard Release" \
    -keystoreFile "${APP_KEYSTORE}" -keystorePwd "${PASS}" \
    -subCaCertFile "${SIGN_DIR}/subCA.cer" \
    -rootCaCertFile "${SIGN_DIR}/rootCA.cer" \
    -outForm certChain \
    -outFile "${SIGN_DIR}/FullKeyboard_app.pem" \
    -validity 3650

# 5. Build the unsigned debug profile JSON, embedding the leaf app certificate.
# If you need to install on a real device, replace the empty "device-ids" array
# with the target UDID obtained via: hdc shell bm get --udid
python3 - <<PYEOF
import json, re, os

pem_path = "${SIGN_DIR}/FullKeyboard_app.pem"
with open(pem_path, "r", encoding="utf-8") as f:
    pem_text = f.read()
leaf = re.search(r"-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----\n", pem_text).group(0)

profile = {
    "version-name": "2.0.0",
    "version-code": 2,
    "uuid": "fe686e1b-3770-4824-a938-961b140a7c98",
    "validity": {"not-before": 1610519532, "not-after": 1893456000},
    "type": "debug",
    "bundle-info": {
        "developer-id": "OpenHarmony",
        "development-certificate": leaf,
        "bundle-name": "ime.fullkeyboard.harmony",
        "apl": "normal",
        "app-feature": "hos_normal_app"
    },
    "acls": {"allowed-acls": [""]},
    "permissions": {"restricted-permissions": [""]},
    "debug-info": {"device-ids": [], "device-id-type": "udid"},
    "issuer": "pki_internal"
}
with open("${SIGN_DIR}/UnsignedDebugProfile.json", "w", encoding="utf-8") as f:
    json.dump(profile, f, indent=2)
PYEOF

# 6. Sign the profile with the SDK debug profile key.
java -jar "${SDK_LIB}/hap-sign-tool.jar" sign-profile \
    -mode localSign \
    -keyAlias "openharmony application profile debug" -keyPwd "${PASS}" \
    -profileCertFile "${SIGN_DIR}/OpenHarmonyProfileDebug.pem" \
    -inFile "${SIGN_DIR}/UnsignedDebugProfile.json" \
    -signAlg SHA256withECDSA \
    -keystoreFile "${SIGN_DIR}/OpenHarmony.p12" -keystorePwd "${PASS}" \
    -outFile "${SIGN_DIR}/FullKeyboardDebug.p7b"

echo "Debug signing material generated in ${SIGN_DIR}:"
ls -l "${SIGN_DIR}"
