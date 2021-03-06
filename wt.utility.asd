;;;; -*- Mode: LISP -*-

(defsystem wt.utility
  :version "0.0.0"
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :license "BSD 3-Clause"
  :depends-on (:alexandria
               :cl-cont
               :closer-mop
               :trivial-garbage
               :maxpc
               (:feature :sbcl (:require :sb-introspect)))
  :defsystem-depends-on (:wt.vendor)
  :components ((:module "utility"
                        :serial t
                        :components ((:file "package")
                                     (:file "macro")
                                     (:file "function")
                                     (:file "class")
                                     (:file "tree")
                                     (:file "reflective")
                                     (:file "variable")
                                     (:file "parser"))))
  :in-order-to ((test-op (test-op :wt.utility/test)))
  :perform (load-op :after (o c)
                    #+lispworks
                    (pushnew :utility hcl:*packages-for-warn-on-redefinition*)))

(defsystem wt.utility/test
  :depends-on (:wt.utility
               :wt.test)
  :components ((:module "test/utility"
                        :serial t
                        :components ((:file "package")
                                     (:file "helper")
                                     (:file "variable"))))
  :perform (test-op (o c)
                    (symbol-call :test :run! :utility-test)))
