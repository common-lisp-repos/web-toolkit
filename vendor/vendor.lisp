(in-package :vendor)

(defun system-dependencies (&optional test)
  (let ((all-deps nil))
    (labels ((add-deps (system-name)
               (check-type system-name string)
               (let* ((system (asdf:find-system system-name))
                      (deps (asdf:system-depends-on system)))
                 (loop for dep in deps
                    do (let ((dep-name
                              (cond
                                ;; (:version :fare-utils "1.0.0")
                                ;; (:feature (:or :sbcl :ccl) :cl+ssl)
                                ((listp dep)
                                 (case (car dep)
                                   (:version (second dep))
                                   (:feature (when (stringp (third dep))
                                               (third dep))) ;; ignore (:require "...")
                                   (t (error "Don't know how to handle dependency ~A" dep))))
                                ((stringp dep) dep))))
                         (when (stringp dep-name)
                           (unless (search "wt." dep-name)
                             (pushnew dep-name all-deps :test 'string-equal))
                           (add-deps dep-name)))))))
      (add-deps (if test "wt/test" "wt"))
      (sort all-deps 'string<))))

(defparameter *vendors* '()
  "List of (system system-asd-pathname)")

(defun parse-vendor-line (line)
  (loop for index from 0
     for char = (aref line index)
     when (eq char #\Space)
     do (return (list (subseq line 0 index) (subseq line (1+ index) (length line))))))

(defun read-vendor-file ()
  (let ((vendor.txt (merge-pathnames
                     "vendor.txt"
                     (asdf:system-source-directory
                      (asdf:find-system "wt")))))
    (when (probe-file vendor.txt)
      (with-open-file (stream vendor.txt)
        (loop for line = (read-line stream nil nil)
           while line
           for (system path) = (parse-vendor-line line)
           when (and system path)
           collect (list system (merge-pathnames
                                 (format nil "vendor/~A" path)
                                 (asdf:system-source-directory
                                  (asdf:find-system "wt")))))))))

(defun register ()
  (loop for (name pathname) in (read-vendor-file)
     when (probe-file pathname)
     do
       (setf (gethash name asdf/source-registry::*source-registry*) pathname)
     else do
       (error "ASD file for system ~S not found: ~S" name pathname)))
