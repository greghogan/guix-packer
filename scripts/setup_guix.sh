#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# The packaged release version
GUIX_VERSION=1.1.0

ARCH=$(uname -m)
NPROCS=$(nproc --all)

CURRENT_GUIX=/var/guix/profiles/per-user/root/current-guix
function WGET() { wget --progress=dot:mega "$@"; }

# Download Guix package and signature
WGET https://ftp.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz
WGET https://ftp.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig

# Verify signature for download
while
  timeout 10 gpg --keyserver na.pool.sks-keyservers.net --recv-keys 3CE464558A84FDC69DB40CFB090B11993D9AEBB5
  ! gpg --verify guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig
do
  echo "Retrying GPG keyserver in 5 seconds"
  sleep 5
done

rm -f guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig

# Unpack and install
tar -C / --warning=no-timestamp -xf guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz
rm -f guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz

# Create the group and user accounts for build users
groupadd --system guixbuild
for i in $(seq -w 1 "${NPROCS}"); do
  useradd -g guixbuild -G guixbuild \
    -d /var/empty -s "$(command -v nologin)" \
    -c "Guix build user ${i}" --system \
    "guixbuilder${i}"
done

# Run the daemon, and set it to automatically start on boot;
# overwrite potential (blank) patched file from setup_system.sh
/bin/cp -f ${CURRENT_GUIX}/lib/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service
# make a copy of the original file which is used in setup_system.sh to modify the Guix service
# to build on an ephemeral disk if present on the system
cp /etc/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service.orig
systemctl start guix-daemon && systemctl enable guix-daemon

# Make the Info version of this manual available there
ln -s ${CURRENT_GUIX}/share/info/* /usr/local/share/info

# Use substitutes from ci.guix.gnu.org
${CURRENT_GUIX}/bin/guix archive --authorize < ${CURRENT_GUIX}/share/guix/ci.guix.gnu.org.pub