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
         "fio"))
        (_ `()))
    '("binutils"
      "coreutils"
      "curl"
      "diffutils"
      "dos2unix"
      "git"
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
      "parallel"
      "pdsh"
      "pkg-config"
      "poke"
      "socat"
      "tar"
      "time"
      "zstd")))
  (packages->manifest
   `(,custom-utf8-locales))))
