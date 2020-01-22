#!/bin/bash

set -e

TARGET_FILE=rawsrc/LaunchDarklyVersion.brs
TEMP_FILE=${TARGET_FILE}.tmp

sed "s/    return \".*\"/    return \"${LD_RELEASE_VERSION}\"/" "${TARGET_FILE}" > "${TEMP_FILE}"
mv "${TEMP_FILE}" "${TARGET_FILE}"
