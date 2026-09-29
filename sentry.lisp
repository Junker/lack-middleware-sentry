(defpackage lack.middleware.sentry
  (:use #:cl)
  (:export #:*lack-middleware-sentry*
           #:*sensitive-headers*
           #:*sensitive-env*))
(in-package :lack.middleware.sentry)

(defparameter *sensitive-headers*
  '("authorization"
    "cookie"
    "set-cookie"
    "x-forwarded-for"
    "x-real-ip"))

(defparameter *sensitive-env*
  '(:lack.session.options
    :lack.session
    :cookies))

(defparameter *lack-middleware-sentry*
  (lambda (app)
    (lambda (env)
      (handler-bind ((error (err)
                            (let* ((headers (getf env :headers))
                                   (extras (append (prepare-env env)
                                                   (prepare-headers headers))))
                              (ignore-errors
                               (sentry-client:capture-exception err
                                                                :extras extras)))))
        (funcall app env)))))


(defun prepare-env (env)
  (loop :for (name val) :on env :by #'cddr
        :collect (cons (symbol-name name)
                       (if (member name *sensitive-env*)
                           "[Filtered]"
                           (format nil "~A" val)))))

(defun prepare-headers (headers)
  (loop :for val :being :each :hash-values :of headers :using (hash-key name)
        :collect (cons (uiop:strcat "|HEADER: " name)
                       (if (member name *sensitive-headers* :test #'string=)
                           "[Filtered]"
                           val))))
