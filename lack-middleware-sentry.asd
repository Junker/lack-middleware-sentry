(defsystem "lack-middleware-sentry"
  :version "0.1.0"
  :author "Dmitrii Kosenkov"
  :license "MIT"
  :depends-on ("lack" "sentry-client")
  :components ((:file "sentry")))
