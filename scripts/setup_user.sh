#!/bin/bash -x

# exit immediately on failure (even when piping) and disable filename expansion (globbing)
set -efo pipefail

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html
AWS_EFA_INSTALLER_VERSION=1.15.1

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
cat <<"EOF" >> ~/.bash_profile

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

function guix_compile_guix() {( set -e
        # use `git stash` to preserve changes while cleaning
        DIRTY=$(git status --porcelain)

        [ -n "${DIRTY}" ] && echo -n "stashing ... " && git stash --quiet --include-untracked
        echo -n "cleaning ... " && git clean --quiet -fdx
        [ -n "${DIRTY}" ] && echo -n "popping ... " && git stash pop --quiet >/dev/null
        echo "done"

        ./bootstrap
        ./configure --localstatedir=/var
        make -j`nproc`
)}
export -f guix_compile_guix

# https://guix.gnu.org/manual/en/html_node/Binary-Installation.html
function guix_make_system_binary() {
	make guix-binary.${1:-`uname -m`-linux}.tar.xz
}
export -f guix_make_system_binary

# https://guix.gnu.org/manual/en/html_node/Running-Guix-Before-It-Is-Installed.html
function guix_run_guix_daemon() {
	sudo -E ./pre-inst-env guix-daemon --build-users-group=guixbuild --max-jobs=${1:-1}
}
export -f guix_run_guix_daemon

function guix_environment_guix() {
	guix environment --container guix --ad-hoc git help2man
}
export -f guix_environment_guix

function guix_build_dependents() {
	DEPENDENTS_STRING=$(./pre-inst-env guix refresh -l "$@")
	echo ${DEPENDENTS_STRING}
	DEPENDENTS=$(echo ${DEPENDENTS_STRING} | cut -d: -f2)
	./pre-inst-env guix build --keep-going --verbosity=1 ${DEPENDENTS}
}
export -f guix_build_dependents

function guix_graph_path() {
	for (( i=1; i<=$#; i++ )) ; do
		for (( j=i+1; j<=$#; j++ )) ; do
			I_TO_J=`guix graph --path ${!i} ${!j} 2>&1`
			[ $? -eq 0 ] && echo -e ">> ${!i} depends on ${!j}\n${I_TO_J}"

			J_TO_I=`guix graph --path ${!j} ${!i} 2>&1`
			[ $? -eq 0 ] && echo -e ">> ${!j} depends on ${!i}\n${J_TO_I}"
		done
	done
}
export -f guix_graph_path

function guix_unrebased_from_upstream() {
	{
		for BRANCH in "core-updates" "staging" "master" ; do
			echo ${BRANCH}
			git rev-list --oneline ${BRANCH}..upstream/${BRANCH}
			echo
		done
	} | less --quit-if-one-screen
}
export -f guix_unrebased_from_upstream

function guix_rebase_worktree() {
	for WORKTREE in "$@" ; do
		echo ${WORKTREE}
		pushd ${WORKTREE} > /dev/null
		for BRANCH in "core-updates" "staging" "master" ; do
			if [[ ${WORKTREE} =~ ${BRANCH}* ]] ; then
				git stash -m "rebase upstream/${BRANCH} `date --utc --iso-8601=seconds`"
				git rebase upstream/${BRANCH}
				git stash pop
				[ -f ./configure ] || ./bootstrap
				[ -f ./Makefile ] || ./configure --localstatedir=/var
				make -j`nproc`
			fi
		done
		popd > /dev/null
	done
}
export -f guix_rebase_worktree
EOF

# configure screen
cat <<EOF >> ~/.screenrc
# See the Screen FAQ,
#   "Q: My xterm scrollbar does not work with screen."
#   http://www4.cs.fau.de/~jnweiger/screen-faq.html
termcapinfo xterm ti@:te@

# This line makes Detach and Re-attach without losing the regions/windows layout
layout save default

# Increase the default scrollback
defscrollback 10000
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

# install AWS EFA (Elastic Fabric Adaptor); for supported instance types and AMIs see
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-amis
if "${INSTALL_EFA}" ; then
  WGET https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-${AWS_EFA_INSTALLER_VERSION}.tar.gz aws-efa-installer.tar.gz
  tar xf aws-efa-installer.tar.gz && rm -f aws-efa-installer.tar.gz
  cd aws-efa-installer || exit
  sudo ./efa_installer.sh -y || exit
  cd .. || exit
  rm -rf aws-efa-installer
fi

# clear command history
> ~/.bash_history && history -c
