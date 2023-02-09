#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

GUIX_PROFILE='/var/guix/profiles/per-user/${USER}/guix-profile'
function RETRY() { while ! "$@"; do echo "Retrying '$*' in 5 seconds" ; sleep 5; done }

# force creation of a profile by updating to the current Guix version, to the (optional) commit
RETRY /var/guix/profiles/per-user/root/current-guix/bin/guix pull ${GUIX_COMMIT:+--commit=${GUIX_COMMIT}}
echo >>~/.bashrc

# import environment variables from Guix package installations
readonly SET_GUIX_PROFILE="export GUIX_PROFILE=${GUIX_PROFILE}"
eval "${SET_GUIX_PROFILE}" && echo "${SET_GUIX_PROFILE}" >>~/.bashrc

# prepend PATH to second search for Guix binaries
readonly SET_GUIX_BINARY_PATH="export PATH=\$HOME/.config/guix/current/bin\${PATH:+:}\$PATH"
eval "${SET_GUIX_BINARY_PATH}" && echo "${SET_GUIX_BINARY_PATH}" >>~/.bashrc

# prepend PATH to first search for user binaries
readonly SET_HOME_BINARY_PATH="export PATH=\$HOME/bin:\$HOME/sbin\${PATH:+:}\$PATH"
eval "${SET_HOME_BINARY_PATH}" && echo "${SET_HOME_BINARY_PATH}" >>~/.bashrc

# install UTF-8 locale and force initial build of Guix
guix package --manifest=/transfer/locales.scm

# the profile does not look to be available until after the installation of the
# custom UTF-8 locales, the first installed package, and the 'eval' will result
# in an error if the source file is not present
readonly SOURCE_GUIX_PROFILE="source \${GUIX_PROFILE}/etc/profile"
eval "${SOURCE_GUIX_PROFILE}" && echo "${SOURCE_GUIX_PROFILE}" >>~/.bashrc

# configure shell resources
cat <<"EOF" >>~/.bashrc

# configure Guix to secondarily search system resources

export INFOPATH=$INFOPATH${INFOPATH:+:}/usr/share/info
export MANPATH=$MANPATH${MANPATH:+:}/usr/share/man
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH${PKG_CONFIG_PATH:+:}/usr/share/pkgconfig

# configure user environment

export HISTCONTROL=ignorespace:ignoredups
export HISTIGNORE="history:ls:pwd:"
export HISTSIZE=9999
export HISTFILESIZE=9999
export HISTTIMEFORMAT="[%F %T] "

# since the prompt string is modified rather than overwritten, only modify the
# string when the conditional return status emoji has not already been inserted
if [[ "$PS1" != *"\xF0\x9F\x94\xA5"* ]]; then
        # insert return status emoji and command number after the leading character (typically a '[' bracket)
        export PS1=${PS1:0:1}'$(if [[ $? == 0 ]]; then printf "  "; else printf "\xF0\x9F\x94\xA5"; fi) \t (\!) '${PS1:1}
fi

export VISUAL=vi
EOF

# configure gdb for any installed Guix debug outputs
cat <<EOF >~/.gdbinit
set debug-file-directory ~/.guix-profile/lib/debug
EOF

# configure less as the git pager to better support UTF-8
cat <<EOF >~/.gitconfig
[core]
	pager = LESSCHARSET=utf-8 less
EOF
