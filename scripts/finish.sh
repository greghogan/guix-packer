#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

ARCH=$(uname -m)

function register_binfmt() {
  CPU=$1
  MAGIC=$2
  MASK=$3

  # registration permitted only after binaries are installed
  echo ":qemu-${CPU}:M::${MAGIC}:${MASK}:/var/guix/profiles/per-user/offload/guix-profile/bin/qemu-${CPU}:F" > /proc/sys/fs/binfmt_misc/register
}

if "$INSTALL_EMULATION_BINARIES" ; then
  # register emulation binaries using the command from the qemu-binfmt-conf script as called by register.sh
  #   https://github.com/qemu/qemu/blob/master/scripts/qemu-binfmt-conf.sh
  #   https://github.com/multiarch/qemu-user-static/blob/master/containers/latest/register.sh
  # documented at https://docs.kernel.org/admin-guide/binfmt-misc.html
  if [ "${ARCH}" != "aarch64" ] ; then
    CPU=aarch64
    MAGIC='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00'
    MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
    register_binfmt $CPU $MAGIC $MASK

    CPU=arm
    MAGIC='\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00'
    MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
    register_binfmt $CPU $MAGIC $MASK
  fi

  if [ "${ARCH}" != "ppc64le" ] ; then
    CPU=ppc64le
    MAGIC='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x15\x00'
    MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\x00'
    register_binfmt $CPU $MAGIC $MASK
  fi

  if [ "${ARCH}" != "x86_64" ] ; then
    CPU=x86_64
    MAGIC='\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'
    MASK='\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
    register_binfmt $CPU $MAGIC $MASK
  fi
fi


# clear command history
> ~/.bash_history && history -c
#!/bin/bash -x


# delete temporary files and clear command history
rm -rf /tmp/* /transfer
> ~/.bash_history && history -c
