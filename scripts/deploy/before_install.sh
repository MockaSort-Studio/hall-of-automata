#!/usr/bin/env bash
# BeforeInstall: prepare the filesystem for the incoming release.
# Runs before CodeDeploy copies the revision files to the host.
set -euo pipefail

# Ensure the app user exists (idempotent).
id -u livedata &>/dev/null || useradd --system --no-create-home --shell /sbin/nologin livedata

# Create install staging directory; remove any leftover tarball from a prior run.
mkdir -p /opt/livedata/install
rm -f /opt/livedata/install/livedata.tar.gz

# Create the directory where the live release will be extracted.
mkdir -p /opt/livedata/current
