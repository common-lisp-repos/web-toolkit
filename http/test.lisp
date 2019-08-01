(in-package :http)

(setf hunchentoot:*catch-errors-p* nil)

(define-handler my-handler () ())

(defmethod handle ((handler my-handler) (request request))
  (setf (response-status *response*) 200)
  (setf (header-field *response* "Content-Type") "text/plain")
  (setf (response-body *response*) "my handler ")

  (let ((response (call-next-handler)))
    (setf (response-body response)
          (format nil "~A ~A"
                  (response-body response)
                  " my handler2"))
    response))

(define-handler your-handler (my-handler) ())

(defmethod handle ((handler your-handler) (request request))
  (setf (response-body *response*)
        (format nil "~A ~A"
                (response-body *response*)
                " your handler2")))

(define-server test-server
    :handler (router
              (:get "/you" your-handler)
              (:get "/me" my-handler))
    :listeners (list
                (listener :port 8001)))
