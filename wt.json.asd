;;;; -*- Mode: LISP -*-

(defsystem wt.json
  :version "0.9.0"
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :license "BSD 3-Clause"
  :depends-on (:alexandria)
  :defsystem-depends-on (:wt.vendor)
  :components ((:module "json"
                        :serial t
                        :components ((:file "package")
                                     (:file "camel-case")
                                     (:file "common")
                                     (:file "object")
                                     (:file "access")
                                     (:file "encode")
                                     (:file "decode"))))
  :in-order-to ((test-op (test-op :wt.json/test)))
  :perform (load-op :after (o c)
                    #+lispworks
                    (pushnew :json hcl:*packages-for-warn-on-redefinition*)))

(defsystem wt.json/test
  :depends-on (:wt.json
               :wt.test)
  :components ((:module "test/json"
                        :components ((:module "json"
                                              ))))
  :perform (test-op (o c)
                    (symbol-call :test :run! :json-test)))
