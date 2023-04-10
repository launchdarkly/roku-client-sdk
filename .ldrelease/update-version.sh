#!/bin/bash

set -e

TARGET_FILE=rawsrc/LaunchDarklyVersion.brs

sed -i "s/    return \".*\"/    return \"${LD_RELEASE_VERSION}\"/" "${TARGET_FILE}"
