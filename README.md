# lack-middleware-sentry

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Common Lisp](https://img.shields.io/badge/Common%20Lisp-library-orange.svg)](https://common-lisp.net/)

[Lack](https://github.com/fukamachi/lack) middleware that reports errors raised
inside your app to [Sentry](https://sentry.io) via
[sentry-client](https://github.com/fukamachi/cl-sentry-client).


## Installation

This system can be installed from [UltraLisp](https://ultralisp.org/) like this:
```lisp
(ql-dist:install-dist "http://dist.ultralisp.org/"
                      :prompt nil)
(ql:quickload :lack-middleware-sentry)
```


## Usage

First, initialize `sentry-client` with your DSN (see its README for details).
Then wrap your app with the middleware:

```lisp
(sentry-client:initialize-sentry-client *my-sentry-dsn*)
												
(lack:builder
  :sentry
  app)
```

The builder keyword `:sentry` resolves to `lack.middleware.sentry:*lack-middleware-sentry*`

### What gets reported

When the app signals an `error`, the middleware calls
`sentry-client:capture-exception` with:

- `:transaction` — `"<request-method> <path-info>"` (e.g. `"GET /users/1"`);
- `:extras` — the whole request `env` plist and its headers.

### Sensitive data

Sensitive headers and env keys are replaced with `"[Filtered]"`.

Both lists are rebindable special variables:

```lisp
(in-package :lack.middleware.sentry)

(pushnew "x-custom-token" *sensitive-headers* :test #'string-equal)
(pushnew :my-env *sensitive-env*)
```
