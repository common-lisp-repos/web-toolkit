(in-package :http-test)

(in-suite :http-test)

(test define-handler-with-instalize-nil
  (it
    (let ((handler-class (define-handler foo () () (:instanize nil))))
      (is (typep handler-class 'http::handler-class)))))

(test define-handler-with-instalize-unset
  (it
    (let ((handler (define-handler foo () ())))
      (is (typep handler 'http::handler)))))

(test define-handler-with-instalize-nil-and-a-function
  (it
    (define-handler test-handler () () (:function (lambda (request))) (:instanize nil))
    (is-true (functionp (http::handler-function (find-class 'test-handler))))
    (is-true (functionp (http::handler-function (make-instance 'test-handler))))
    (is (equal '(request) (http::handler-function-lambda-list (find-class 'test-handler))))
    (is (equal '(request) (http::handler-function-lambda-list (make-instance 'test-handler))))))

(test define-handler-with-instalize-nil-and-a-function-then-change-the-function
  (it
    (define-handler test-handler () () (:function (lambda (request))) (:instanize nil))
    (define-handler test-handler () () (:function (lambda (handler request))) (:instanize nil))
    (is (equal '(handler request) (http::handler-function-lambda-list (find-class 'test-handler))))
    (is (equal '(handler request) (http::handler-function-lambda-list (make-instance 'test-handler))))))

(test define-handler-with-instalize-t-without-function
  (it
    (define-handler test-handler () () (:instanize t))
    (is (equal nil (http::handler-function test-handler)))
    (is (equal nil (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-instalize-t-with-a-function
  (it
    (define-handler test-handler () () (:function (lambda (request))) (:instanize t))
    (is-true (functionp (http::handler-function test-handler)))
    (is (equal '(request) (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-instalize-t-with-a-function-then-change-the-function
  (it
    (define-handler test-handler () () (:function (lambda (request))) (:instanize t))
    (define-handler test-handler () () (:function (lambda (handler request))) (:instanize t))
    (is-true (functionp (http::handler-function test-handler)))
    (is (equal '(handler request) (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-wrong-function-arity
  (it
    (define-handler test-handler () () (:function (lambda (handler request))))
    (signals error (define-handler test-handler () () (:function (lambda (a b c)))))
    ;; Keep function & function-lambda-list untuoched
    (is-true (functionp (http::handler-function test-handler)))
    (is (equal '(handler request) (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-wrong-function-type
  (it
    (define-handler test-handler () () (:function (lambda (handler request))))
    (signals error (define-handler test-handler () () (:function 42)))
    ;; Keep function & function-lambda-list untuoched
    (is-true (functionp (http::handler-function test-handler)))
    (is (equal '(handler request) (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-empty-function
  (it
    (define-handler test-handler () () (:function))
    (is-true (null (http::handler-function test-handler)))
    (is-true (null (http::handler-function-lambda-list test-handler)))))

(test define-handler-with-call-cc-function
  (it
    (define-handler test-handler () () (:function (cl-cont:lambda/cc (request))))
    (is-true (typep (http::handler-function test-handler) 'cl-cont::funcallable/cc))
    (is (equal '(request) (http::handler-function-lambda-list test-handler)))))

(test handler-function-lambda-list
  (it
    (finishes (http::check-handler-function-lambda-list '()))
    (finishes (http::check-handler-function-lambda-list '(request)))
    (finishes (http::check-handler-function-lambda-list '(handler request)))
    (signals error (http::check-handler-function-lambda-list '(handler request xxx)))))

(test invoke-handler
  (it "should return a response"
      (define-handler foo ()
        ()
        (:function (lambda ())))
      (let ((res (http::invoke-handler foo nil)))
        (is (typep res 'response))))

  (it "should return a response"
      (define-handler foo ()
        ()
        (:function (lambda () (reply (status 201)))))
      (let ((res (http::invoke-handler foo nil)))
        (is (typep res 'response))
        (is (equal 201 (status-code (response-status res)))))))

(test call-next-handler
  (it "should be able to call next handler"
      (define-handler foo ()
        ()
        (:function (lambda ()
                     (reply (status 201))
                     (call-next-handler))))

      (define-handler bar (foo)
        ()
        (:function (lambda ()
                     (reply (status 202)))))

      (let ((res (http::invoke-handler bar nil)))
        (is (typep res 'response))
        (is (equal 202 (status-code (response-status res))))))

  (it "should be able to access next handler's response"
      (define-handler foo ()
        ()
        (:function (lambda ()
                     (let ((res (call-next-handler)))
                       (is (equal 202 (status-code (response-status res))))))))

      (define-handler bar (foo)
        ()
        (:function (lambda ()
                     (reply (status 202)))))

      (http::invoke-handler bar nil))

  (it "should be able to call next handler even if there is none"
      (define-handler foo ()
        ()
        (:function (lambda ()
                     (let ((res (call-next-handler)))
                       (is (typep res 'response))))))

      (http::invoke-handler foo nil)))

(test abort-handler
  (it "should abort handler"
      (define-handler foo ()
        ()
        (:function (lambda ()
                     (reply (status 201))
                     (abort-handler)
                     (reply (status 202)))))

      (let ((res (http::invoke-handler foo nil)))
        (is (typep res 'response))
        (is (equal 201 (status-code (response-status res)))))))
