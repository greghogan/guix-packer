#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

# generate and authorize an SSH public key, shared by all nodes in the cluster
ssh-keygen -N "" -t rsa -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# allow root passwordless login for offload builds
sudo cat /root/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# enable the sharing of multiple sessions over a single network connection
# with ControlMaster and ControlPath
mkdir .ssh/sockets

cat <<EOF > ~/.ssh/config
Host *
    LogLevel ERROR
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
EOF
chmod 600 ~/.ssh/config


# configure AWS CLI
mkdir ~/.aws

cat <<EOF > ~/.aws/config
[default]
region=us-east-1
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


# Configure the shell
cat <<EOF >> ~/.bashrc

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
EOF


# Configure screen
cat <<EOF >> ~/.screenrc
# See the Screen FAQ,
#   "Q: My xterm scrollbar does not work with screen."
#   http://www4.cs.fau.de/~jnweiger/screen-faq.html
termcapinfo xterm ti@:te@

# This line makes Detach and Re-attach without losing the regions/windows layout
layout save default
EOF


# Configure htop via bashrc conditional on the number of runtime processors
mkdir -p ~/.config/htop
cat <<EOF_BASH_PROFILE >> ~/.bash_profile

# Configure htop
if [ "\$(nproc --all)" -ge 8 ]; then
  CPU_METERS=\$(
    cat <<-EOF
	left_meters=LeftCPUs2 CPU CPU Memory Memory
	left_meter_modes=1 2 1 1 2
	right_meters=RightCPUs2 Tasks LoadAverage Uptime Clock Hostname
	right_meter_modes=1 2 2 2 2 2
	EOF
  )
else
  CPU_METERS=\$(
    cat <<-EOF
	left_meters=CPU CPU AllCPUs Memory Memory
	left_meter_modes=2 1 1 1 2
	right_meters=Tasks LoadAverage Uptime Clock Hostname
	right_meter_modes=2 2 2 2 2
	EOF
  )
fi

cat <<EOF_HTOPRC > ~/.config/htop/htoprc
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
fields=0 48 17 18 38 39 40 2 46 47 49 13 14 15 16 20 50 1
sort_key=46
sort_direction=1
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


# delete temporary files and clear command history
rm -f packer.pub packer
> ~/.bash_history && history -c
