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
/bin/cp -pf ${CURRENT_GUIX}/lib/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service
# make a copy of the original file which is used in setup_system.sh to modify the Guix service
# to build on an ephemeral disk if present on the system
cp /etc/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service.orig
systemctl start guix-daemon && systemctl enable guix-daemon

# Make the Info version of this manual available there
ln -s ${CURRENT_GUIX}/share/info/* /usr/local/share/info

# Use substitutes from ci.guix.gnu.org
${CURRENT_GUIX}/bin/guix archive --authorize < ${CURRENT_GUIX}/share/guix/ci.guix.gnu.org.pub

# Generate and self-authenticate a new key pair for the daemon, a prerequisite before archives can be exported
${CURRENT_GUIX}/bin/guix archive --generate-key
${CURRENT_GUIX}/bin/guix archive --authorize < /etc/guix/signing-key.pub

# Create template for enabling Guix offload builds; to use, the host name and
# user name must be added and the file renamed by removing the ".template" extension
cat <<EOF > /etc/guix/machines.scm.template
(list (build-machine
        (name "<host name>")
        (systems (list "${ARCH}-linux"))
        (host-key "$(cat /etc/ssh/ssh_host_ed25519_key.pub)")
        (user "<user>")
        (parallel-builds 1)
        (compression "none")))
EOF

# The following packages must be installed on the build host: guix guile guile-ssh

# Prevent warning from Guix when offloading or copying between hosts:
# ssh_known_hosts_read_entries: Failed to open the known_hosts file '/etc/ssh/ssh_known_hosts': No such file or directory
touch /etc/ssh/ssh_known_hosts
