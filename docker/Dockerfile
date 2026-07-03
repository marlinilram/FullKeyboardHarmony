# syntax=docker/dockerfile:1
# Dockerfile for building FullKeyboard HarmonyOS port in an isolated container.
# It installs:
#   - OpenJDK 17 (for signing / Java-based tooling if needed)
#   - Node.js 18 LTS and npm
#   - Huawei OHPM command-line tools
#   - OpenHarmony 5.0.0 (API 12) public SDK from the HuaweiCloud mirror
#   - Hvigor is provided by the project wrapper (hvigorw).

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget git unzip xz-utils python3 python3-pip \
        openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 18 LTS and npm from NodeSource (required by hvigor / ohpm).
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node -v && npm -v

# Hvigor requires an .npmrc in the user home with the Huawei npm registries.
RUN printf 'registry=https://repo.huaweicloud.com/repository/npm/\n@ohos:registry=https://repo.harmonyos.com/npm/\n' > /root/.npmrc

# Install Huawei OHPM command-line tools.
ENV OHOS_TOOLS=/opt/ohos-tools
RUN mkdir -p ${OHOS_TOOLS} && \
    cd ${OHOS_TOOLS} && \
    curl -fsSL -o oh-command-line-tools.zip \
        'https://repo.huaweicloud.com/harmonyos/ohpm/5.0.2/oh-command-line-tools-20240715.zip' && \
    unzip -q oh-command-line-tools.zip && \
    rm oh-command-line-tools.zip && \
    chmod +x ${OHOS_TOOLS}/oh-command-line-tools/ohpm/bin/*

ENV OHPM_HOME=${OHOS_TOOLS}/oh-command-line-tools/ohpm
ENV PATH=${OHPM_HOME}/bin:${PATH}
RUN ${OHPM_HOME}/bin/init && \
    ohpm config set registry https://ohpm.openharmony.cn/ohpm/ && \
    ohpm config set strict_ssl false

# Install OpenHarmony 5.0.0 (API 12) public SDK.
# The official HuaweiCloud archive is a single ~2.5 GB tarball that contains
# inner platform zips.  Download it with wget --continue / infinite retries,
# verify the published SHA-256 checksum, then unzip the inner Linux zips into
# the standard SDK layout: <OHOS_SDK_HOME>/12/{ets,js,native,previewer,toolchains}.
ENV OHOS_SDK_HOME=/opt/ohos-sdk
ENV SDK_VERSION=5.0.0.71
RUN --mount=type=cache,target=/tmp/ohos-sdk-dl \
    set -eux; \
    DL_DIR=/tmp/ohos-sdk-dl; \
    mkdir -p ${DL_DIR}; \
    cd ${DL_DIR}; \
    SDK_URL="https://repo.huaweicloud.com/openharmony/os/5.0.0-Release/ohos-sdk-windows_linux-public.tar.gz"; \
    SHA_URL="${SDK_URL}.sha256"; \
    SDK_TAR="ohos-sdk-windows_linux-public.tar.gz"; \
    if [ ! -f "${SDK_TAR}" ]; then \
        echo "Downloading OpenHarmony 5.0.0 Public SDK (this is large, please be patient)..."; \
    fi; \
    wget --continue --tries=0 --read-timeout=60 --progress=dot:giga \
        -O "${SDK_TAR}" "${SDK_URL}"; \
    wget --continue --tries=0 --read-timeout=60 \
        -O "${SDK_TAR}.sha256" "${SHA_URL}"; \
    echo "Verifying SDK checksum..."; \
    EXPECTED_SHA=$(tr -d '[:space:]' < "${SDK_TAR}.sha256"); \
    ACTUAL_SHA=$(sha256sum "${SDK_TAR}" | awk '{print $1}'); \
    if [ "${EXPECTED_SHA}" != "${ACTUAL_SHA}" ]; then \
        echo "Checksum mismatch: expected ${EXPECTED_SHA}, got ${ACTUAL_SHA}" >&2; \
        exit 1; \
    fi; \
    echo "Extracting SDK..."; \
    mkdir -p extracted; \
    tar -xzf "${SDK_TAR}" -C extracted; \
    mkdir -p ${OHOS_SDK_HOME}/12; \
    for zip in extracted/linux/*.zip; do \
        echo "Unzipping $(basename ${zip})..."; \
        unzip -q -o "${zip}" -d ${OHOS_SDK_HOME}/12; \
    done; \
    ls -la ${OHOS_SDK_HOME}/12

ENV DEVECO_SDK_HOME=${OHOS_SDK_HOME}
ENV OHOS_BASE_SDK_HOME=${OHOS_SDK_HOME}
ENV PATH=${OHOS_SDK_HOME}/12/toolchains:${PATH}

WORKDIR /workspace

# Default build command: install OHPM dependencies, then npm/pnpm Hvigor
# dependencies, then build the entry HAP using the local Hvigor CLI.
CMD ["/bin/bash", "-c", "cd /workspace && ohpm install && cd /workspace/entry && ohpm install && cd /workspace && npm install && node node_modules/@ohos/hvigor/bin/hvigor.js assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon"]
