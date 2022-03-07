(use-modules
 (gnu packages base))

(define custom-utf8-locales
  (make-glibc-utf8-locales
   glibc
   #:locales (list "en_US")
   #:name "custom-utf8-locales"))

(concatenate-manifests
 (list
  (specifications->manifest
   '("abseil-cpp"
     "boost"
     "ccache"
     "clang"
     "cmake"
     "cxxopts"
     "fmt"
     "folly"
     "gcc-toolchain"
     "gdb"
     "gflags"
     "git"
     "gmp"
     "info-reader"
     "json-modern-cxx"
     "make"
     "man-db"
     "man-pages"
     "pkg-config"
     "valgrind"))
  (packages->manifest
   `(,custom-utf8-locales))))
