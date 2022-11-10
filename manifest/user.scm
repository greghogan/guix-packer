(use-modules
 (guix packages)
 (gnu packages base)
 (ice-9 match))

(define custom-utf8-locales
  (make-glibc-utf8-locales
   glibc
   #:locales (list "en_US")
   #:name "custom-utf8-locales"))

(concatenate-manifests
 (list
  (specifications->manifest
   (append
    (match (%current-system)
      ((or "x86_64-linux" "i686-linux")
       `("cpuid"
         "diffoscope"
         "fio"
         "ripgrep"
         "tealdeer"
         "turbostat"))
        (_ `()))
    '("bat"
      "binutils"
      "btop"
      "coreutils"
      "csvkit"
      "curl"
      "diffutils"
      "dos2unix"
      "gawk"
      "git"
      "git:send-email"
      "grep"
      "gron"
      "htop"
      "iftop"
      "info-reader"
      "iotop"
      "iperf"
      "jq"
      "less"
      "man-db"
      "man-pages"
      "netcat"
      "nss-certs"
      "numactl"
      "openssh"
      "parallel"
      "pdsh"
      "pkg-config"
      "poke"
      "pv"
      "python-yq"
      "recutils"
      "rsync"
      "sed"
      "socat"
      "sshpass"
      "strace"
      "tar"
      "time"
      "tree"
      "util-linux"
      "vmtouch"
      "zstd"

      ;; Guix setup
      "emacs"
      "emacs-geiser"
      "emacs-magit"
      "emacs-paredit"
      "emacs-yasnippet"
      "guile"
      "vim")))
  (packages->manifest
   `(,custom-utf8-locales))))
