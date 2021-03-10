#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

GUIX_PROFILE='/var/guix/profiles/per-user/${USER}/guix-profile'

# force creation of a profile by updating to the current Guix version, to the (optional) commit
/var/guix/profiles/per-user/root/current-guix/bin/guix pull ${GUIX_COMMIT:+--commit=${GUIX_COMMIT}}

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
guix install glibc-utf8-locales

readonly SET_GUIX_LOCPATH="export GUIX_LOCPATH=\${GUIX_PROFILE}/lib/locale"
eval "${SET_GUIX_LOCPATH}" && echo "${SET_GUIX_LOCPATH}" >>~/.bashrc

# the profile does not look to be available until after the installation of
# glibc-utf8-locales, the first installed package, and the 'eval' will result
# in an error if the source file is not present
readonly SOURCE_GUIX_PROFILE="source \${GUIX_PROFILE}/etc/profile"
eval "${SOURCE_GUIX_PROFILE}" && echo "${SOURCE_GUIX_PROFILE}" >>~/.bashrc
