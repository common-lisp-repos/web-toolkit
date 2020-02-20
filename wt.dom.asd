;;;; -*- Mode: LISP -*-

(defsystem wt.dom
  :version "0.0.0"
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :depends-on ()
  :serial t
  :components ((:module "dom"
                        :serial t
                        :components ((:file "package")
                                     )))
  :in-order-to ((test-op (test-op :wt.dom/test))))

(defsystem wt.dom/test
  :depends-on (:wt.dom
               :wt.test)
  :serial t
  :components ((:module "test"
                        :components ((:module "dom"
                                              :serial t
                                              :components ((:file "package")
                                                           )))))
  :perform (test-op (o c)
                    (symbol-call :test :run! :dom-test)))
