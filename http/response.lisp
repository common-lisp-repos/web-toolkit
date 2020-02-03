(in-package :http)

(defclass response ()
  ((status
    :initarg :status
    :initform nil
    :accessor response-status)
   (header
    :initarg :header
    :initform (make-instance 'header)
    :accessor response-header)
   (body
    :initarg :body
    :initform nil
    :accessor response-body)))

(defmethod print-object ((response response) stream)
  (print-unreadable-object (response stream :type t)
    (let ((*print-pretty* t))
      (pprint-logical-block (stream nil)
        (pprint-indent :block -8 stream)
        (pprint-newline :mandatory stream)
        (format stream "~A" (response-status response))
        (pprint-indent :block -8 stream)
        (pprint-newline :mandatory stream)
        (format stream "~A" (response-header response))
        (pprint-indent :block -8 stream)
        (pprint-newline :mandatory stream)
        (format stream "~A" (response-body response))))))

(defvar *response* nil)

(defgeneric response-status (response))

(defgeneric (setf response-status) (value response))

(defgeneric response-header (response))

(defgeneric (setf response-header) (value response))

(defgeneric response-body (response))

(defgeneric (setf response-body) (value response))

(defmethod (setf response-status) ((value integer) response)
  (let ((status (gethash value
                         *status-code-mapping-table*)))
    (setf (response-status response) status)))

(defmethod (setf response-status) ((value symbol) response)
  (let ((status (gethash (make-keyword value)
                         *status-keyword-mapping-table*)))
    (setf (response-status response) status)))

(defmethod (setf response-status) ((value status) response)
  (setf (slot-value response 'status) value))

(defmethod header-fields ((response response))
  (let ((header (response-header response)))
    (header-fields header)))

(defmethod (setf header-fields) (value (response response))
  (let ((header (response-header response)))
    (setf (header-fields header) value)))

(defmethod find-header-field ((response response) name)
  (find-header-field (response-header response) name))

(defun read-status-line (stream &key (parse t))
  (let ((line (read-line stream)))
    (unless (emptyp line)
      (if parse
          (parse-status-line line)
          line))))

(defun parse-status-line (line)
  (unless (every #'printable-ascii-char-p line)
    (error "Non-ASCII character in status line"))
  (destructuring-bind (http-version status-code reason-phase)
      (cl-ppcre:split "\\s+" line :limit 3)
    (list http-version (parse-integer status-code) reason-phase)))

(defun write-status-line (stream http-version status-code reason-phase)
  (check-type http-version string)
  (check-type status-code (or string integer))
  (check-type reason-phase string)
  (let ((line (format nil "~A ~A ~A" http-version status-code reason-phase)))
    (write-string line stream)
    (write-sequence +crlf+ stream)
    (+ (length line) (length +crlf+))))

(defun read-response-body (stream)
  (alexandria::read-stream-content-into-byte-vector stream))

(defun write-response-body (stream response)
  (let ((body (response-body response)))
    (typecase body
      (string (length (write-string body stream)))
      (vector (length (write-sequence body stream))))))

(defun read-response (stream)
  (let ((status-line (read-status-line stream)))
    (let ((header (read-header stream)))
      (let ((body (read-response-body stream)))
        (let ((status-code (second status-line)))
          (make-instance 'response
                         :status status-code
                         :header header
                         :body body))))))

(defgeneric write-response (stream response)
  (:method (stream (response response))
    (+
     (write-status-line stream "HTTP/1.1"
                        (status-code (response-status response))
                        (status-reason-phrase (response-status response)))
     (write-header stream (response-header response))
     (write-response-body stream response))))

(trace write-response write-response-body write-header write-status-line)
