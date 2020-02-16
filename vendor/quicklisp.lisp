(in-package :vendor)

(defun install ()
  (loop
     with vendor = (merge-pathnames
                       "vendor/"
                       (asdf:system-source-directory
                        (asdf:find-system "wt")))
     with vendor.txt = (merge-pathnames
                        "vendor.txt"
                        (asdf:system-source-directory
                         (asdf:find-system "wt")))
     for dependency in (reduce-systems (system-dependencies "wt/test"))
     for system = (ql::find-system dependency)
     for release = (ql::release system)
     for archive = (ql::ensure-local-archive-file release)
     for tar = (merge-pathnames "release-install.tar" (uiop:temporary-directory))
     for source = (merge-pathnames
                   (format nil "~A.asd" dependency)
                   (pathname-as-directory
                    (merge-pathnames (slot-value release 'ql::prefix) vendor)))
     do (format t "~S~%" (merge-pathnames (slot-value release 'ql::prefix) vendor))
       (ensure-directories-exist tar)
       (ensure-directories-exist vendor)
       (ql::gunzip archive tar)
       (ql::unpack-tarball tar :directory vendor)
       (unless (probe-file source)
         (error "ASD file for system ~S not found: ~S" dependency source))
     collect (list dependency (format nil "~A/~A.asd" (slot-value release 'ql::prefix) dependency))
     into vendors
     finally
       (setf vendors (sort vendors 'string< :key 'first))
       (setf *vendors* vendors)
       (with-open-file (stream vendor.txt
                               :direction :output
                               :if-does-not-exist :create
                               :if-exists :supersede)
         (loop for (system source) in vendors
            do (format stream "~A ~A~C" system source #\Newline)))))

(defun reduce-systems (names)
  (loop for name in names
     for system = (or (ql::find-system name)
                      (format t "System ~S not found by quicklisp~%" name))
     for release = (and system (ql::release system))
     for project = (and release (slot-value release 'ql::project-name))
     unless (or (null project) (find project projects :test 'equal))
     collect project into projects and collect name into systems
     finally (return systems)))

(defun component-present-p (value)
  "Helper function for DIRECTORY-PATHNAME-P which checks whether VALUE
   is neither NIL nor the keyword :UNSPECIFIC."
  (and value (not (eql value :unspecific))))

(defun directory-pathname-p (pathspec)
  "Returns NIL if PATHSPEC \(a pathname designator) does not designate
a directory, PATHSPEC otherwise.  It is irrelevant whether file or
directory designated by PATHSPEC does actually exist."
  (and
   (not (component-present-p (pathname-name pathspec)))
   (not (component-present-p (pathname-type pathspec)))
   pathspec))

(defun pathname-as-directory (pathspec)
  "Converts the non-wild pathname designator PATHSPEC to directory
form."
  (let ((pathname (pathname pathspec)))
    (when (wild-pathname-p pathname)
      (error "Can't reliably convert wild pathnames."))
    (cond ((not (directory-pathname-p pathspec))
           (make-pathname :directory (append (or (pathname-directory pathname)
                                                 (list :relative))
                                             (list (file-namestring pathname)))
                          :name nil
                          :type nil
                          :defaults pathname))
          (t pathname))))
