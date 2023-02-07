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
   '("guile"
     "guile-ssh"
     "guix"
     "qemu:static"))
  (packages->manifest
   `(,custom-utf8-locales))))
