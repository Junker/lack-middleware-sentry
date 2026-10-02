(defsystem "lack-middleware-sentry"
  :version "0.1.0"
  :author "Dmitrii Kosenkov"
  :license "MIT"
  :description "Lack middleware for reporting errors to Sentry."
  :depends-on ("lack" "sentry-client")
  :components ((:file "sentry"))
  :in-order-to ((test-op (test-op "lack-middleware-sentry/tests"))))

(defsystem "lack-middleware-sentry/tests"
  :author "Dmitrii Kosenkov"
  :license "MIT"
  :description "Tests for lack-middleware-sentry"
  :depends-on ("lack-middleware-sentry"
               "sentry-client"
               "cl-mock"
               "parachute"
               "alexandria")
  :components ((:file "tests"))
  :perform (test-op (o c) (uiop:symbol-call :parachute :test
                                            :lack-middleware-sentry/tests)))
