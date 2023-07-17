#!/bin/bash -x

# exit immediately on failure (even when piping), treat unset variables and
# parameters as an error, and disable filename expansion (globbing)
set -eufo pipefail

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

alias tmux='tmux -u'

alias wordiff='git diff --word-diff=color --word-diff-regex=.'

eval `lesspipe.sh`

export GUIX_BUILD_OPTIONS="--cores=1 --keep-going --max-jobs=$(getconf _NPROCESSORS_ONLN) --verbosity=1"

function silence_offload_status() {
        # filter logs cluttering stderr with status updates every second
        "$@" 2> >(grep -v "acquired build slot\|normalized load on machine" >&2)
}
export -f silence_offload_status

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
	guix environment --container guix --ad-hoc git help2man less
}
export -f guix_environment_guix

function guix_build_dependents() {
	local NUM_BUILDS

	REGEX_NUMBER='^[0-9]+$'
	if [[ $1 =~ ${REGEX_NUMBER} ]]; then
		NUM_BUILDS=$1
		shift
	fi

	DEPENDENTS_STRING=$(./pre-inst-env guix refresh -l "$@")
	DEPENDENTS=$(echo ${DEPENDENTS_STRING} | cut -d: -f2)

	if [ -n "${NUM_BUILDS}" ]; then
		DEPENDENTS=$(echo ${DEPENDENTS} | xargs --max-args 1 | shuf | head --lines ${NUM_BUILDS} | xargs)
	fi
	echo "Building ${DEPENDENTS}"
	./pre-inst-env guix build --no-grafts --keep-going --verbosity=1 ${DEPENDENTS}
}
export -f guix_build_dependents

function guix_watch_builds() {
	watch 'find /tmp -maxdepth 1 -name "guix-build-*" -printf "%TH:%TM:%.2TS  %f\n" | sort | cat --number-nonblank'
}
export -f guix_watch_builds

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
		for BRANCH in master ; do
			echo ${BRANCH}
			UPSTREAM_BRANCH=upstream/${BRANCH%%-*}
			git rev-list --oneline ${BRANCH}..${UPSTREAM_BRANCH}
			echo
		done
	} | less --quit-if-one-screen
}
export -f guix_unrebased_from_upstream

function guix_rebase_worktree() {
	for WORKTREE in "$@" ; do
		echo ${WORKTREE}
		pushd ${WORKTREE} > /dev/null
		for BRANCH in master ; do
			echo ${BRANCH}
			UPSTREAM_BRANCH=upstream/${BRANCH%%-*}
			if [[ ${WORKTREE} =~ ${BRANCH}* ]] ; then
				git stash -m "rebase ${UPSTREAM_BRANCH} `date --utc --iso-8601=seconds`"
				git rebase ${UPSTREAM_BRANCH}
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


# configure emacs
cat <<EOF >> ~/.emacs
;; Highlight cursor line
(global-hl-line-mode +1)

;; Highlight the pair of delimiters under the cursor
(show-paren-mode 1)
(setq show-paren-delay 0)

;; Add auto-completion to Geiser
(ac-config-default)
(require 'ac-geiser)
(add-hook 'geiser-mode-hook 'ac-geiser-setup)
(add-hook 'geiser-repl-mode-hook 'ac-geiser-setup)
(eval-after-load "auto-complete"
  '(add-to-list 'ac-modes 'geiser-repl-mode))

;; Configure Paredit
(require 'paredit)
(autoload 'enable-paredit-mode "paredit" "Turn on pseudo-structural editing of Lisp code." t)
(add-hook 'scheme-mode-hook #'enable-paredit-mode)
EOF


# configure guile
cat <<EOF >> ~/.guile
(use-modules
 (ice-9 colorized)
 (ice-9 readline))

(activate-colorized)

(activate-readline)
(readline-set! history-length 10000)
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


# configure tmux
cat <<"EOF" >> ~/.tmux.conf
set-option -g history-limit 100000

# change prefix to Ctrl + Space
unbind C-Space
set -g prefix C-Space
bind C-Space send-prefix

# add binding for vertical split
bind-key "|" split-window -h -c "#{pane_current_path}"
bind-key "\\" split-window -fh -c "#{pane_current_path}"

# add binding for horizontal split
bind-key "-" split-window -v -c "#{pane_current_path}"
bind-key "_" split-window -fv -c "#{pane_current_path}"

# swap windows
bind -r "<" swap-window -d -t -1
bind -r ">" swap-window -d -t +1

# preserve path when creating new panes
bind c new-window -c "#{pane_current_path}"

# reload config file
bind r source-file ~/.tmux.conf \; display-message "tmux config reloaded"

# replace toggle layout with switch to last window
bind Space last-window

# switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# enable mouse mode
set -g mouse on

#
# plugin configuration
#

run-shell $GUIX_PROFILE/share/tmux-plugins/resurrect/resurrect.tmux
set -g @resurrect-strategy-vim 'session'
set -g @resurrect-strategy-nvim 'session'
set -g @resurrect-capture-pane-contents 'on'

run-shell $GUIX_PROFILE/share/tmux-plugins/continuum/continuum.tmux
set -g @continuum-save-interval '5'
EOF


# configure vim
cat <<"EOF" >> ~/.vimrc
set encoding=utf-8
set fileencoding=utf-8

" include Guix plugins
let $GUIX_VIMPATH="$GUIX_PROFILE/share/vim/vimfiles/"
let &rtp=$GUIX_VIMPATH.','.&rtp

" default delay is too unresponsive for gitgutter plugin
set updatetime=100

" clear search with Ctrl+/
noremap <silent> <c-_> :let @/ = ""<CR>

" trim trailing whitespace with F5
nnoremap <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar><CR>

" reopen the last edited position in files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" do not auto-indent or auto-comment on paste
set paste
set pastetoggle=<F2>

" toggle absolute and relative numbers automatically based on mode
" see vim-numbertoggle [https://github.com/jeffkreeftmeijer/vim-numbertoggle]
:set number

:augroup numbertoggle
:  autocmd!
:  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
:  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
:augroup END

" open files to linenumber with form <filename>:<line number>
" copied from file_line.vim [https://www.vim.org/scripts/script.php?script_id=2184]
function! s:gotoline()
        let file = bufname("%")

        " :e command calls BufRead even though the file is a new one.
        " As a workarround Jonas Pfenniger<jonas@pfenniger.name> added an
        " AutoCmd BufRead, this will test if this file actually exists before
        " searching for a file and line to goto.
        if (filereadable(file))
                return
        endif

        " Accept file:line:column: or file:line:column and file:line also
        let names =  matchlist( file, '\(.\{-1,}\):\%(\(\d\+\)\%(:\(\d*\):\?\)\?\)\?$')

        if empty(names)
                return
        endif

        let file_name = names[1]
        let line_num  = names[2] == ''? '0' : names[2]
        let  col_num  = names[3] == ''? '0' : names[3]

        if filereadable(file_name)
                let l:bufn = bufnr("%")
                exec ":bwipeout " l:bufn

                exec "keepalt edit " . file_name
                exec ":" . line_num
                exec "normal! " . col_num . '|'
                if foldlevel(line_num) > 0
                        exec "normal! zv"
                endif

                exec "normal! zz"
        endif
endfunction

autocmd! BufNewFile *:* nested call s:gotoline()
autocmd! BufRead *:* nested call s:gotoline()
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
