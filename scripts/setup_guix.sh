#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

ARCH=$(uname -m)

CURRENT_GUIX=/var/guix/profiles/per-user/root/current-guix
function RETRY() { while ! "$@"; do echo "Retrying '$*' in 5 seconds" ; sleep 5; done }
function WGET() { wget --progress=dot:mega "$@"; }

# download Guix package and signature
WGET https://ftp.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz
WGET https://ftp.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig

# verify signature for download
while
  # key fetch from https://guix.gnu.org/manual/en/html_node/Binary-Installation.html
  timeout 10 sh -c "wget 'https://sv.gnu.org/people/viewgpg.php?user_id=127547' -qO - | gpg --import -"
  ! gpg --verify guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig
do
  echo "Retrying GPG keyserver in 5 seconds"
  sleep 5
done

rm -f guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz.sig

# unpack and install
tar -C / --warning=no-timestamp -xf guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz
rm -f guix-binary-${GUIX_VERSION}.${ARCH}-linux.tar.xz

# create the group and user accounts for build users
groupadd --system guixbuild
for i in $(seq -w 1 16); do
  useradd -g guixbuild -G guixbuild \
    -d /var/empty -s "$(command -v nologin)" \
    -c "Guix build user ${i}" --system \
    "guixbuilder${i}"
done

# make the Info version of this manual available
ln -s ${CURRENT_GUIX}/share/info/* /usr/local/share/info

# enable substitutes from ci.guix.gnu.org
if "${GUIX_SUBSTITUTES}" ; then
  ${CURRENT_GUIX}/bin/guix archive --authorize < ${CURRENT_GUIX}/share/guix/ci.guix.gnu.org.pub
fi

# generate and self-authenticate a new key pair for the daemon, a prerequisite before archives can be exported
${CURRENT_GUIX}/bin/guix archive --generate-key
${CURRENT_GUIX}/bin/guix archive --authorize < /etc/guix/signing-key.pub

# create template for enabling Guix offload builds; to use, the host name and
# user name must be added and the file renamed by removing the ".template" extension
case "${ARCH}" in
  aarch64)
    SYSTEMS='"armhf-linux" "aarch64-linux" "i686-linux" "x86_64-linux"'
    ;;
  x86_64)
    SYSTEMS='"aarch64-linux" "i686-linux" "x86_64-linux"'
    ;;
  *)
    echo "unsupported ARCH=${ARCH}"
    exit 1
esac

cat <<EOF > /etc/guix/machines.scm.template
(list (build-machine
        (name "<host name>")
        (systems (list ${SYSTEMS}))
        (host-key "$(cat /etc/ssh/ssh_host_ed25519_key.pub | sed s/\ $//)")
        (user "offload")
        (overload-threshold 0.9)
        (parallel-builds 3)
        (compression "none")
        (speed 1.0)))
EOF

ln -s /etc/guix/ /usr/local/etc/guix

# prevent cloud-init from changing ssh host keys on new instances
sed -i 's/^ssh_deletekeys:   true$/ssh_deletekeys:   false/' /etc/cloud/cloud.cfg

# allow members of the wheel to sudo without entering a password
sed -i 's/^%wheel\tALL=(ALL)\tALL$/# %wheel\tALL=(ALL)\tALL/' /etc/sudoers
sed -i 's/^# %wheel\tALL=(ALL)\tNOPASSWD: ALL$/%wheel\tALL=(ALL)\tNOPASSWD: ALL/' /etc/sudoers

# run the daemon, and set it to automatically start on boot;
# overwrite potential (blank) patched file from setup_system.sh
/bin/cp -pf ${CURRENT_GUIX}/lib/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service
# make a copy of the original file which is used in setup_system.sh to modify the Guix service
# to build on an ephemeral disk if present on the system
cp /etc/systemd/system/guix-daemon.service /etc/systemd/system/guix-daemon.service.orig

# bootstrap builds fail on EBS filesystems so build on tmpfs if no substitutes
if ! "${GUIX_SUBSTITUTES}" ; then
  # from patch in setup_system.sh
  MAX_JOBS="$(echo "define log2(x) { if (x == 1) return (1); return 1+log2(x/2); } ; log2(`nproc`)" | bc)"
  EXEC_START="--max-silent-time=1800 --max-jobs=${MAX_JOBS}"
  patch -d/ -p0 /etc/systemd/system/guix-daemon.service.orig -o /etc/systemd/system/guix-daemon.service <<EOF_PATCH
--- guix-daemon.service
+++ guix-daemon.service
@@ -7,7 +7,7 @@

 [Service]
 ExecStart=/var/guix/profiles/per-user/root/current-guix/bin/guix-daemon \\
-    --build-users-group=guixbuild --discover=no
+    --build-users-group=guixbuild --discover=no ${EXEC_START}
 Environment='GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale' LC_ALL=en_US.utf8
 RemainAfterExit=yes
 StandardOutput=syslog
@@ -16,7 +16,7 @@ StandardError=syslog
 # See <https://lists.gnu.org/archive/html/guix-devel/2016-04/msg00608.html>.
 # Some package builds (for example, go@1.8.1) may require even more than
 # 1024 tasks.
-TasksMax=8192
+TasksMax=16384
 
 [Install]
 WantedBy=multi-user.target
EOF_PATCH

  mount -t tmpfs -o size=100% swap /tmp

  # copy both /gnu and /var/guix to support running this code for future updates
  rsync -aHAXR /gnu /tmp
  rsync -aHAXR /var/guix /tmp

  mount --bind /tmp/gnu /gnu
  mount --bind /tmp/var/guix /var/guix

  systemctl start guix-daemon

  RETRY /var/guix/profiles/per-user/root/current-guix/bin/guix pull ${GUIX_COMMIT:+--commit=${GUIX_COMMIT}}

  systemctl stop guix-daemon

  umount /gnu
  umount /var/guix

  rsync -aHAX /tmp/gnu/ /gnu/
  rsync -aHAX /tmp/var/guix/ /var/guix/

  umount /tmp

  # use RAM disk on boot
  cat <<-EOF >> /etc/fstab
	tmpfs                                         /tmp        tmpfs  rw,mode=1777,size=100%   0 0
	EOF
fi

systemctl enable --now guix-daemon

# create user for local software builds
useradd -G wheel build

# share SSH configuration to the build user
sudo cp -a ~/.ssh ~build
chown -R build: ~build/.ssh

# remove configuration preventing 'root' login
sed -i 's/^.*ssh-rsa/ssh-rsa/' ~build/.ssh/authorized_keys


# create user for offload builds as specified above in the machines.scm template
useradd -G wheel offload

# share SSH configuration to the offload user
sudo cp -a ~/.ssh ~offload
chown -R offload: ~offload/.ssh

# remove configuration preventing 'root' login
sed -i s/^.*ssh-rsa/ssh-rsa/ ~offload/.ssh/authorized_keys


# prevent warning from Guix when offloading or copying between hosts:
# ssh_known_hosts_read_entries: Failed to open the known_hosts file '/etc/ssh/ssh_known_hosts': No such file or directory
touch /etc/ssh/ssh_known_hosts
