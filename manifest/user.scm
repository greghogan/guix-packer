(use-modules (guix packages)
             (ice-9 match))

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
     "glibc-utf8-locales"
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
