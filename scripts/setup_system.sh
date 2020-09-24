#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# enable and set PAM limits
cat <<EOF >> /etc/pam.d/common-session
session required pam_limits.so
EOF

cat <<EOF >> /etc/security/limits.conf
soft nofile 1048576
hard nofile 1048576
soft core unlimited
hard core unlimited
EOF


# mount attached volumes on startup
chmod +x /etc/rc.local
cat <<"EOF" >> /etc/rc.local

# remove existing volume directories
# run from root and silence output
pushd / > /dev/null
rmdir -p --ignore-fail-on-non-empty volumes/*
popd > /dev/null

format_and_mount() {
    disk=$1
    mount_options=$2

    # require block device to not be a symbolic link;
    # EBS devices may be symlinked xvda to nvme0n1
    if [ -b "/dev/${disk}" -a ! -h "/dev/${disk}" ]; then
        blockdev --setra 512 /dev/${disk}
        echo 1024 > /sys/block/${disk}/queue/nr_requests

        # attempt to format disk
        /sbin/mkfs.ext4 -m 0 ${mount_options} /dev/${disk}

        # mount if format successful
        if [ $? -eq 0 ]; then
            mkdir -p /volumes/${disk}
            mount -o init_itable=0 /dev/${disk} /volumes/${disk}

            mkdir -p /volumes/${disk}/tmp
            chmod 777 /volumes/${disk}/tmp
        fi
    fi
}

# ephemeral disks are symlinked xvda to nvme0n1, ...
#for id in {a..z}; do
#    format_and_mount xvd${id} &
#done

for id in {0..31}; do
    format_and_mount nvme${id}n1 "-E nodiscard" &
done

# don't continue until disks have finished mounting
wait

# If an ephemeral disk is present, update the Guix service to build from the ephemeral disk;
# the root disk is 8 GB by default and fio has been updated with a ceph dependency requiring 17+ GB
# to build, which can be accommodated during build with an ephemeral disk
cp /etc/systemd/system/guix-daemon.service.orig /etc/systemd/system/guix-daemon.service
if [ -d "/volumes/nvme1n1" ]; then
  patch -d/ -p0 /etc/systemd/system/guix-daemon.service.orig -o /etc/systemd/system/guix-daemon.service <<EOF_PATCH
--- /etc/systemd/system/guix-daemon.service.orig
+++ /etc/systemd/system/guix-daemon.service
@@ -7,7 +7,7 @@

 [Service]
 ExecStart=/var/guix/profiles/per-user/root/current-guix/bin/guix-daemon --build-users-group=guixbuild
-Environment='GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale' LC_ALL=en_US.utf8
+Environment='GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale' LC_ALL=en_US.utf8 TMPDIR=/volumes/nvme1n1/tmp
 RemainAfterExit=yes
 StandardOutput=syslog
 StandardError=syslog
EOF_PATCH
fi
systemctl daemon-reload && systemctl restart guix-daemon
EOF
