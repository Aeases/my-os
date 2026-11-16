#!/usr/bin/env bash
#
# Install kernel packages and akmods, bypassing dracut/rpm-ostree triggers.
# From Bazzite: https://github.com/ublue-os/bazzite/blob/main/build_files/bazzite/03-install-kernel-akmods.sh
#
set -xeuo pipefail

echo "::group::Install kernel akmods"
trap 'echo "::endgroup::"' EXIT

# -- Create shims to bypass kernel install triggers --
# Create shim scripts to prevent kernel installation from triggering dracut
# and rpm-ostree, allowing the build to progress with minimal impact.
echo "==> Creating kernel install shims..."

pushd /usr/lib/kernel/install.d
    mv -f 05-rpmostree.install 05-rpmostree.install.bak
    mv -f 50-dracut.install 50-dracut.install.bak
    printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
    printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
    chmod +x 05-rpmostree.install 50-dracut.install
popd

# -- Remove existing kernel packages --
# Erase all existing kernel-related packages to avoid conflicts.
echo "==> Removing existing kernel packages..."
declare -a KERNEL_PACKAGES=(
    "kernel"
    "kernel-core"
    "kernel-modules"
    "kernel-modules-core"
    "kernel-modules-extra"
)

for pkg in "${KERNEL_PACKAGES[@]}"; do
    echo "    Erasing '${pkg}'..."
    rpm --erase "${pkg}" --nodeps
done

# -- Cleanup leftover modules --
# Remove leftover module directories not covered by kernel-* packages.
echo "==> Cleaning up leftover modules..."
rm -rf /usr/lib/modules

# -- Install kernel packages --
# Install kernel RPMs from /tmp/kernel-rpms using dnf5.
echo "==> Installing kernel packages..."
dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm \
    /tmp/kernel-rpms/kernel-devel-*.rpm

# -- Versionlock kernel packages --
# Prevent kernel packages from being updated by dnf.
echo "==> Version locking kernel packages..."
dnf5 versionlock add \
    kernel \
    kernel-devel \
    kernel-devel-matched \
    kernel-core \
    kernel-modules

# -- Install common akmods --
# Install common kernel module RPMs (v4l2loopback).
echo "==> Installing common akmods..."
dnf5 -y install \
    /tmp/rpms/{common,kmods}/*v4l2loopback*.rpm

# -- Install extra akmods --
# Install extra kernel module RPMs (ryzen_smu).
echo "==> Installing extra akmods..."
dnf5 -y install \
    /tmp/rpms/{extra,kmods-extra}/*ryzen_smu*.rpm

# -- Restore original kernel install.d scripts --
# Move the backed-up install scripts back to their original names.
echo "==> Restoring original kernel install.d scripts..."

pushd /usr/lib/kernel/install.d
    mv -f 05-rpmostree.install.bak 05-rpmostree.install
    mv -f 50-dracut.install.bak 50-dracut.install
popd

# -- Remove boot files --
# Clear old kernel images and boot artifacts from /boot.
# Intentionally clear /boot in the image being built.
# shellcheck disable=SC2115
rm -rf /boot/* || true
rm -rf /boot/.* || true
# ^^^^^ https://github.com/ublue-os/bazzite/blob/main/build_files/cleanup.sh
