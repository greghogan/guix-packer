#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html
AWS_EFA_INSTALLER_VERSION=1.14.1

ARCH=$(uname -m)

function WGET() { until wget --tries=1 --timeout=10 --progress=dot:mega "$1" -O "$2"; do rm -f "$2"; done }

# share SSH configuration from root user
sudo cp -a /root/.ssh ~
sudo chown -R "${USER}": ~/.ssh

# remove configuration preventing 'root' login
sed -i s/^.*ssh-rsa/ssh-rsa/ ~/.ssh/authorized_keys


# configure AWS CLI
mkdir ~/.aws

cat <<EOF > ~/.aws/config
[default]
region=us-east-2
output=json
s3 =
  max_concurrent_requests = 10
  max_queue_size = 10000
  multipart_threshold = 5GB
  multipart_chunksize = 5GB
EOF

cat <<EOF > ~/.aws/credentials
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF


# configure the shell
cat <<EOF >> ~/.bash_profile

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
EOF

# configure screen
cat <<EOF >> ~/.screenrc
# See the Screen FAQ,
#   "Q: My xterm scrollbar does not work with screen."
#   http://www4.cs.fau.de/~jnweiger/screen-faq.html
termcapinfo xterm ti@:te@

# This line makes Detach and Re-attach without losing the regions/windows layout
layout save default
EOF

# configure htop via bash_profile conditional on the number of runtime processors
mkdir -p ~/.config/htop
cat <<EOF_BASH_PROFILE >> ~/.bash_profile

# Configure htop
if [ "\$(nproc --all)" -ge 8 ]; then
  CPU_METERS=\$(
    cat <<-EOF
	left_meters=LeftCPUs2 CPU CPU Memory Memory
	left_meter_modes=1 2 1 1 2
	right_meters=RightCPUs2 Tasks LoadAverage Uptime Hostname DiskIO NetworkIO
	right_meter_modes=1 2 2 2 2 2 2
	EOF
  )
else
  CPU_METERS=\$(
    cat <<-EOF
	left_meters=CPU CPU AllCPUs Memory Memory
	left_meter_modes=2 1 1 1 2
	right_meters=Tasks LoadAverage Uptime Hostname DiskIO NetworkIO
	right_meter_modes=2 2 2 2 2 2
	EOF
  )
fi

cat <<EOF_HTOPRC > ~/.config/htop/htoprc
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
fields=0 48 17 18 38 39 40 2 46 47 49 13 14 15 16 20 50 1
sort_key=46
sort_direction=-1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=0
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=1
highlight_megabytes=1
highlight_threads=1
tree_view=0
header_margin=0
detailed_cpu_time=1
cpu_count_from_zero=1
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
delay=15
\${CPU_METERS}
EOF_HTOPRC
EOF_BASH_PROFILE

# system utility packages
if [ "${ARCH}" = "x86_64" ]; then
guix install \
  cpuid \
  fio
fi

guix install \
  binutils \
  coreutils \
  curl \
  diffoscope \
  diffutils \
  dos2unix \
  git \
  htop \
  iftop \
  info-reader \
  iotop \
  iperf \
  jq \
  less \
  man-db \
  man-pages \
  netcat \
  numactl \
  parallel \
  pdsh \
  pkg-config \
  poke \
  socat \
  tar \
  time \
  zstd
source ~/.bashrc

# install AWS EFA (Elastic Fabric Adaptor)
# this also installs Amazon's OpenMPI build among other installed packages
# note: no current support for aarch64 instances:
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types
if [ "${ARCH}" = "x86_64" ]; then
  WGET https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-${AWS_EFA_INSTALLER_VERSION}.tar.gz aws-efa-installer.tar.gz
  tar xf aws-efa-installer.tar.gz && rm -f aws-efa-installer.tar.gz
  cd aws-efa-installer || exit
  sudo ./efa_installer.sh -y || exit
  cd .. || exit
  rm -rf aws-efa-installer
fi

# remove old generations but defer cleanup to the final script
guix gc --collect-garbage=0 --delete-generations

# clear command history
> ~/.bash_history && history -c
