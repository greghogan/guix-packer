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
cat <<EOF >> /etc/rc.local

# remove existing volume directories
# run from root and silence output
pushd / > /dev/null
rmdir -p --ignore-fail-on-non-empty volumes/*
popd > /dev/null

format_and_mount() {
    disk=\$1
    mount_options=\$2

    # require block device to not be a symbolic link;
    # EBS devices may be symlinked xvda to nvme0n1
    if [ -b "/dev/\${disk}" -a ! -h "/dev/\${disk}" ]; then
        blockdev --setra 512 /dev/\${disk}
        echo 1024 > /sys/block/\${disk}/queue/nr_requests

        # attempt to format disk
        /sbin/mkfs.ext4 -m 0 \${mount_options} /dev/\${disk}

        # mount if format successful
        if [ \$? -eq 0 ]; then
            mkdir -p /volumes/\${disk}
            mount -o init_itable=0 /dev/\${disk} /volumes/\${disk}

            mkdir -p /volumes/\${disk}/tmp
            chmod 777 /volumes/\${disk}/tmp
        fi
    fi
}

# ephemeral disks are symlinked xvda to nvme0n1, ...
for id in {0..31}; do
    format_and_mount nvme\${id}n1 "-E nodiscard" &
done

# don't continue until disks have finished mounting
wait

# grow maximum number of jobs as the base-2 logarithm of the number of cores;
# there is no back-off due to CPU load as with offload builds; when substitutes
# are enabled this supports concurrent downloads
MAX_JOBS="\$(echo "define log2(x) { if (x == 1) return (1); return 1+log2(x/2); } ; log2(\`nproc\`)" | bc)"
EXEC_START="--max-silent-time=86400 --max-jobs=\${MAX_JOBS}"

if ! "${GUIX_SUBSTITUTES}" ; then
  # from https://guix.gnu.org/manual/en/html_node/Invoking-guix_002ddaemon.html:
  #   setting --gc-keep-derivations to yes causes liveness to flow from outputs to derivations, and
  #   setting --gc-keep-outputs to yes causes liveness to flow from derivations to outputs. When
  #   both are set to yes, the effect is to keep all the build prerequisites (the sources, compiler,
  #   libraries, and other build-time tools) of live objects in the store, regardless of whether
  #   these prerequisites are reachable from a GC root. This is convenient for developers since it
  #   saves rebuilds or downloads.
  EXEC_START="\${EXEC_START} --gc-keep-outputs=yes --gc-keep-derivations=yes"
fi

patch -d/ -p0 /etc/systemd/system/guix-daemon.service.orig -o /etc/systemd/system/guix-daemon.service <<EOF_PATCH
--- guix-daemon.service
+++ guix-daemon.service
@@ -7,7 +7,7 @@

 [Service]
 ExecStart=/var/guix/profiles/per-user/root/current-guix/bin/guix-daemon \\\\
-    --build-users-group=guixbuild --discover=no
+    --build-users-group=guixbuild --discover=no \${EXEC_START}
 Environment='GUIX_LOCPATH=/var/guix/profiles/per-user/root/guix-profile/lib/locale' LC_ALL=en_US.utf8
 StandardOutput=syslog
 StandardError=syslog
@@ -22,7 +22,7 @@
 # See <https://lists.gnu.org/archive/html/guix-devel/2016-04/msg00608.html>.
 # Some package builds (for example, go@1.8.1) may require even more than
 # 1024 tasks.
-TasksMax=8192
+TasksMax=16384
 
 [Install]
 WantedBy=multi-user.target
EOF_PATCH
systemctl daemon-reload && systemctl restart guix-daemon
EOF
