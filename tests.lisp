(defpackage lack-middleware-sentry/tests
  (:use #:cl
        #:parachute)
  (:import-from #:lack.middleware.sentry
                #:*lack-middleware-sentry*)
  (:import-from #:cl-mock
                #:with-mocks
                #:answer
                #:invocations)
  (:export #:run-tests))
(in-package :lack-middleware-sentry/tests)

(defun assoc-value* (alist key)
  (cdr (assoc key alist :test #'string=)))

(defun make-env (&rest plist)
  (if (getf plist :headers)
      plist
      (append plist (list :headers (make-hash-table :test #'equal)))))

(defun failing-app (&key (message "boom"))
  (lambda (env)
    (declare (ignore env))
    (error message)))

(defun ok-app ()
  (lambda (env)
    (declare (ignore env))
    '(200 () ("ok"))))

(defun middleware-call (app env)
  (funcall (funcall *lack-middleware-sentry* app) env))

(defun capture-calls ()
  (mapcar (lambda (invocation)
            (destructuring-bind (name condition . key-args) invocation
              (declare (ignore name))
              (append (list :condition condition)
                      key-args)))
          (invocations 'sentry-client:capture-exception)))

(define-test middleware-passes-response-through
    (with-mocks ()
      (answer sentry-client:capture-exception nil)
      (is equal '(200 () ("ok"))
          (middleware-call (ok-app) (make-env :request-method "GET")))))

(define-test middleware-captures-and-propagates
    (with-mocks ()
      (answer sentry-client:capture-exception nil)
      ;; Error must propagate out of the middleware untouched.
      (is eql 'app-boom
          (handler-case
              (progn (middleware-call (failing-app :message "app-boom")
                                      (make-env :request-method "GET" :path-info "/x"))
                     :no-error)
            (error (e)
              (if (search "app-boom" (princ-to-string e))
                  'app-boom
                  :masked-by-secondary))))
      ;; One capture, with the original condition object.
      (is eql 1 (length (invocations 'sentry-client:capture-exception)))
      (let ((condition (getf (first (capture-calls)) :condition)))
        (true (typep condition 'error))
        (is equal "app-boom" (format nil "~A" condition)))))

(define-test middleware-propagates-when-capture-fails
  ;; capture-exception failing must not mask the app error.
  (with-mocks ()
    (answer sentry-client:capture-exception
      (error "sentry network down"))
    (is eql 'app-boom
        (handler-case
            (progn (middleware-call (failing-app :message "app-boom")
                                    (make-env :request-method "GET"))
                   :no-error)
          (error (e)
            (if (search "app-boom" (princ-to-string e))
                'app-boom
                :masked-by-secondary))))))

(define-test middleware-transaction
    (with-mocks ()
      (answer sentry-client:capture-exception nil)
      (handler-case
          (middleware-call (failing-app)
                           (make-env :request-method "GET" :path-info "/users/1"))
        (error ()))
      (is string= "GET /users/1"
          (getf (first (capture-calls)) :transaction))))

(define-test sensitive-headers-filtered
    (with-mocks ()
      (answer sentry-client:capture-exception nil)
      (let ((headers (make-hash-table :test #'equal)))
        (setf (gethash "authorization" headers) "Bearer deadbeef"
              (gethash "cookie" headers) "session=abc"
              (gethash "user-agent" headers) "Mozilla/5.0")
        (handler-case
            (middleware-call (failing-app) (make-env :request-method "GET" :headers headers))
          (error ()))
        (let ((extras (getf (first (capture-calls)) :extras)))
          (is string= "[Filtered]"
              (assoc-value* extras "|HEADER: authorization"))
          (is string= "[Filtered]"
              (assoc-value* extras "|HEADER: cookie"))
          (is string= "Mozilla/5.0"
              (assoc-value* extras "|HEADER: user-agent"))))))

(define-test sensitive-env-filtered
    (with-mocks ()
      (answer sentry-client:capture-exception nil)
      (handler-case
          (middleware-call (failing-app)
                           (make-env :request-method "GET"
                                     :lack.session '((user-id . 42))
                                     :cookies '(("session" . "abc"))))
        (error ()))
      (let ((extras (getf (first (capture-calls)) :extras)))
        (is string= "[Filtered]" (assoc-value* extras "LACK.SESSION"))
        (is string= "[Filtered]" (assoc-value* extras "COOKIES"))
        (is string= "GET" (assoc-value* extras "REQUEST-METHOD")))))

(defun run-tests ()
  (parachute:test 'lack-middleware-sentry/tests))
