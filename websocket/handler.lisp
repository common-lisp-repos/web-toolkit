(in-package :websocket)

(defmacro make-handler (form)
  (when form
    (unless (member (first form) '(lambda lambda/cc))
      (error "Malformed handler form ~A, expect LAMBDA or LAMBDA/CC expression" form)))
  form)

(defun compute-endpoint-class-precedence-list (instance-or-class)
  (let ((class (cond
                 ((typep instance-or-class 'standard-class) instance-or-class)
                 (t (class-of instance-or-class)))))
    (loop for class in (compute-class-precedence-list class)
       when (typep class 'endpoint-class)
       collect class)))

(defun compute-session-class-precedence-list (instance-or-class)
  (let ((class (cond
                 ((typep instance-or-class 'standard-class) instance-or-class)
                 (t (class-of instance-or-class)))))
    (loop for class in (compute-class-precedence-list class)
       when (typep class 'session-class)
       collect class)))

(defmacro define-handler-lambda-list-checker (handler-name &key (max-length 0)
                                                     allowed-keys)
  (let ((checker-name (intern (format nil "CHECK-~A-LAMBDA-LIST" handler-name))))
    (with-gensyms (lambda-list/s lambda-list-groups/s required-parameters/s
                                 keyword-parameters/s allowed-keys/s
                                 keyword-name/s)
      `(eval-when (:compile-toplevel :load-toplevel :execute)
         (defun ,checker-name (,lambda-list/s)
           (let ((,lambda-list-groups/s (multiple-value-list
                                         (parse-ordinary-lambda-list
                                          ,lambda-list/s))))
             (let ((,required-parameters/s (first ,lambda-list-groups/s)))
               (when (> (length ,required-parameters/s) ,max-length)
                 (error "Malformed lambda-list for ~A: ~A" ',handler-name ,lambda-list/s)))
             (let ((,keyword-parameters/s (fourth ,lambda-list-groups/s)))
               (let ((,allowed-keys/s ,allowed-keys))
                 (loop for ((,keyword-name/s nil)) in ,keyword-parameters/s
                    unless (member ,keyword-name/s ,allowed-keys/s)
                    do (error "Malformed lambda-list for ~A: ~A" ',handler-name ,lambda-list/s))))))))))

(define-handler-lambda-list-checker open-handler
    :max-length 2)

(defun invoke-open-handler/1 (endpoint-class endpoint session)
  (when-let ((open-handler (endpoint-open-handler endpoint-class))
             (open-handler-code (endpoint-open-handler-code endpoint-class)))
    (let ((open-handler-lambda-list (first open-handler-code)))
      (let ((lambda-list-groups (multiple-value-list
                                 (parse-ordinary-lambda-list
                                  open-handler-lambda-list))))
        (let ((required-parameters (first lambda-list-groups)))
          (ignore-errors
            (handler-bind ((error (lambda (e)
                                    (invoke-error-handler endpoint session e))))
              (cond
                ((= 0 (length required-parameters)) (funcall open-handler))
                ((= 1 (length required-parameters)) (funcall open-handler session))
                ((= 2 (length required-parameters)) (funcall open-handler endpoint session))))))))))

(defun invoke-open-handler (endpoint session)
  (let ((endpoint-classes (reverse
                           (compute-endpoint-class-precedence-list endpoint))))
    (loop for endpoint-class in endpoint-classes
       do (invoke-open-handler/1 endpoint-class endpoint session))))

(define-handler-lambda-list-checker close-handler
    :max-length 2
    :allowed-keys '(:code :reason))

(defun invoke-close-handler/1 (endpoint-class endpoint session code reason)
  (when-let ((close-handler (endpoint-close-handler endpoint-class))
             (close-handler-code (endpoint-close-handler-code endpoint-class)))
    (let ((close-handler-lambda-list (first close-handler-code)))
      (let ((lambda-list-groups (multiple-value-list
                                 (parse-ordinary-lambda-list
                                  close-handler-lambda-list))))
        (let ((required-parameters (first lambda-list-groups))
              (keyword-parameters (fourth lambda-list-groups)))
          (let ((arguments (cond
                             ((= 0 (length required-parameters)) nil)
                             ((= 1 (length required-parameters)) `(,session))
                             ((= 2 (length required-parameters)) `(,endpoint
                                                                   ,session)))))
            (when (find :code keyword-parameters :key 'caar)
              (appendf arguments (list :code code)))
            (when (find :reason keyword-parameters :key 'caar)
              (appendf arguments (list :reason reason)))
            (ignore-errors
              (handler-bind ((error (lambda (e)
                                      (invoke-error-handler endpoint session e))))
                (apply close-handler arguments)))))))))

(defun invoke-close-handler (endpoint session code reason)
  (let ((endpoint-classes (reverse
                           (compute-endpoint-class-precedence-list endpoint))))
    (loop for endpoint-class in endpoint-classes
       do (invoke-close-handler/1 endpoint-class endpoint session code reason))))

(define-handler-lambda-list-checker error-handler
    :max-length 3)

(defun invoke-error-handler/1 (endpoint-class endpoint session error)
  (when-let ((error-handler (endpoint-error-handler endpoint-class))
             (error-handler-code (endpoint-error-handler-code endpoint-class)))
    (let ((error-handler-lambda-list (first error-handler-code)))
      (let ((lambda-list-groups (multiple-value-list
                                 (parse-ordinary-lambda-list
                                  error-handler-lambda-list))))
        (let ((required-parameters (first lambda-list-groups)))
          ;; TODO: add error-fallback-handler
          (ignore-errors
            (cond
              ((= 0 (length required-parameters)) (funcall error-handler))
              ((= 1 (length required-parameters)) (funcall error-handler error))
              ((= 2 (length required-parameters)) (funcall error-handler session error))
              ((= 3 (length required-parameters)) (funcall error-handler endpoint session error)))))))))

(defun invoke-error-handler (endpoint session error)
  (let ((endpoint-classes (reverse
                           (compute-endpoint-class-precedence-list endpoint))))
    (loop for endpoint-class in endpoint-classes
       do (invoke-error-handler/1 endpoint-class endpoint session error))))

(define-handler-lambda-list-checker message-handler
    :max-length 2)

(defun invoke-message-handler/1 (endpoint session-class session message)
  (when-let ((message-handler (session-message-handler session-class))
             (message-handler-code (session-message-handler-code session-class)))
    (let ((message-handler-lambda-list (first message-handler-code)))
      (let ((lambda-list-groups (multiple-value-list
                                 (parse-ordinary-lambda-list
                                  message-handler-lambda-list))))
        (let ((required-parameters (first lambda-list-groups)))
          (ignore-errors
            (handler-bind ((error (lambda (e)
                                    (invoke-error-handler endpoint session e))))
              (cond
                ((= 0 (length required-parameters)) (funcall message-handler))
                ((= 1 (length required-parameters)) (funcall message-handler message))
                ((= 2 (length required-parameters)) (funcall message-handler session message))))))))))

(defun invoke-message-handler (endpoint session message)
  (let ((session-classes (reverse
                          (compute-session-class-precedence-list session))))
    (loop for session-class in session-classes
       do (invoke-message-handler/1 endpoint session-class session message))))
