(in-package :websocket)

(define-constant +magic+
    "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  :test #'string=
  :documentation "Fixed magic WebSocket UUIDv4 key use in handshakes")

(define-condition websocket-error (simple-error)
  ((code :initarg :code :reader websocket-error-code))
  (:documentation "Superclass for all errors related to WebSocket."))

(defun websocket-error (code format-control &rest format-arguments)
  (error 'websocket-error
         :code code
         :format-control format-control
         :format-arguments format-arguments))

(define-condition text-received ()
  ((text
    :initarg :text
    :initform nil)))

(define-condition binary-received ()
  ((data
    :initarg :data
    :initform nil)))

(define-condition close-received ()
  ((code
    :initarg :code
    :initform nil)
   (reason
    :initarg :reason
    :initform nil)))

(defun symbol-function-p (symbol)
  (if (and (fboundp symbol)
           (not (macro-function symbol))
           (not (special-operator-p symbol)))
      (symbol-function symbol)
      nil))

(defun decide-endpoint-session-class (endpoint request)
  (let ((object (endpoint-session-class endpoint)))
    (typecase object
      (null 'session)
      (symbol (cond
                ((find-class object nil) object)
                ((symbol-function-p object)
                 (let ((value (funcall object request)))
                   (typecase value
                     (symbol value)
                     (t (error "Expect symbol")))))))
      (function (let ((value (funcall object request)))
                  (typecase value
                    (symbol value)
                    (t (error "Expect symbol"))))))))

(defun make-session-instance (session-class connection request)
  (make-instance session-class
                 :connection connection
                 :opening-uri (request-uri request)
                 :opening-header (request-header request)))

(defun handle-user-endpoint-request (endpoint request)
  (handler-bind ((error (lambda (c)
                          (trivial-backtrace:print-backtrace c))))
    (handle-handshake request)
    (let* ((stream (http::request-stream request))
           (connection (make-instance 'connection
                                      :state :open
                                      :input-stream stream
                                      :output-stream stream)))

      (let ((session-class (decide-endpoint-session-class endpoint request)))
        (let ((session (make-session-instance session-class connection request)))

          (let ((result (invoke-open-handler endpoint session)))
            (when (typep result 'session)
              (setf session result)))

          (handler-bind ((websocket-error
                          (lambda (error)
                            (with-slots (code) error
                              ;; (close-connection connection
                              ;;                   :status status
                              ;;                   :reason (princ-to-string error))
                              (invoke-error-handler endpoint session error)
                              (return-from handle-user-endpoint-request))))
                         (babel-encodings:character-decoding-error
                          (lambda (error)
                            (close-connection connection
                                              :code 1007
                                              :reason "Bad UTF-8")
                            (invoke-error-handler endpoint session error)
                            (return-from handle-user-endpoint-request)))
                         (error
                          (lambda (error)
                            (close-connection connection
                                              :code 1011
                                              :reason "Internal error")
                            (invoke-error-handler endpoint session error)
                            (return-from handle-user-endpoint-request)))

                         (text-received
                          (lambda (c)
                            (let ((message (slot-value c 'text)))
                              (invoke-message-handler session message))))

                         (binary-received
                          (lambda (c)
                            (let ((message (slot-value c 'data)))
                              (invoke-message-handler session message))))

                         (close-received
                          (lambda (c)
                            (let ((code (slot-value c 'code))
                                  (reason (slot-value c 'reason)))
                              (invoke-close-handler endpoint session code reason)))))
            (with-slots (state) connection
              (loop do (handle-frame connection
                                     (receive-frame connection))
                 while (not (or (eq state :closed)
                                (eq state :closing)))))))))))

(defun websocket-uri (path host &optional ssl)
  "Form WebSocket URL (ws:// or wss://) URL."
  (format nil "~:[ws~;wss~]://~a~a" ssl host path))

(defun handle-handshake (request)
  (let ((connection (header-field-value
                     (find-header-field request "Connection")))
        (upgrade (header-field-value
                  (find-header-field request "Upgrade"))))
    (unless (and
             connection
             (member "Upgrade" (cl-ppcre:split "\\s*,\\s*" connection)
                     :test #'string-equal)
             upgrade
             (string-equal "WebSocket" upgrade))
      (error "Not websocket request")))
  (let ((requested-version (header-field-value
                            (find-header-field request "Sec-WebSocket-Version"))))
    (unless (equal "13" requested-version)
      (websocket-error 1002
                       "Unsupported websocket version ~a" requested-version)))
  (when (find-header-field request "Sec-WebSocket-Draft")
    (websocket-error 1002 "Websocket draft is unsupported"))
  (let* ((key (header-field-value
               (find-header-field request "Sec-WebSocket-Key")))
         (key+magic (concatenate 'string key +magic+)))
    (reply (header-field "Sec-WebSocket-Accept"
                         (base64:usb8-array-to-base64-string
                          (ironclad:digest-sequence
                           'ironclad:sha1
                           (ironclad:ascii-string-to-byte-array
                            key+magic))))))
  (let ((origin (header-field-value
                 (find-header-field request "Sec-WebSocket-Origin"))))
    (reply (header "Sec-WebSocket-Origin" origin)))
  (let* ((host (header-field-value
                (find-header-field request "Host")))
         (uri (request-uri request))
         (path (uri:uri-path uri)))
    (reply (header "Sec-WebSocket-Location"
                   (websocket-uri path host nil))))
  (let ((protocol (header-field-value
                   (find-header-field request "Sec-WebSocket-Protocol"))))
    (when protocol
      (reply (header "Sec-WebSocket-Protocol"
                     (first (cl-ppcre:split "\\s*,\\s*" protocol))))))
  (reply
   (status :switching-protocols)
   (header :upgrade "WebSocket")
   (header :connection "Upgrade")
   (header :content-type "application/octet-stream"))

  #+lispworks
  (setf (stream:stream-read-timeout (http::request-stream request)) nil
        (stream:stream-write-timeout (http::request-stream request)) nil)

  (let ((stream (flex:make-flexi-stream (http::request-stream request)
                                        :external-format (flex:make-external-format :latin1 :eol-style :lf))))
    (format stream "HTTP/1.1 ~D ~A~C~C" 101 "Switching Protocols" #\Return #\Linefeed)
    (loop for header-field in (header-fields *response*)
       for name = (header-field-name header-field)
       for value = (header-field-value header-field)
       do (hunchentoot::write-header-line name value stream))
    (format stream "~C~C" #\Return #\Linefeed)
    (force-output stream))

  (http::request-stream request))
