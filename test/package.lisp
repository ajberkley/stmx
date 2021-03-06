;; -*- lisp -*-

;; This file is part of STMX.
;; Copyright (c) 2013-2016 Massimiliano Ghilardi
;;
;; This library is free software: you can redistribute it and/or
;; modify it under the terms of the Lisp Lesser General Public License
;; (http://opensource.franz.com/preamble.html), known as the LLGPL.
;;
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the Lisp Lesser General Public License for more details.


(in-package :cl-user)

(defpackage #:stmx.test
  (:use #:cl
        #:bordeaux-threads
        #:fiveam
        #:stmx.lang
        #:stmx
        #:stmx.util)

  ;; no need for closer-mop version of typep and subtypep;
  ;; they even cause some tests to fail
  #+cmucl
  (:shadowing-import-from #:cl
                          #:typep
                          #:subtypep)

  (:import-from #:stmx
                #:+invalid-version+  #:set-tvar-value-and-version
                #:raw-value-of #:tx-read-of #:tx-write-of

                #:tlog  #:make-tlog
                #:rerun-error #:rerun
                #:retry-error #:retry
                #:commit
                #:valid? #:valid-and-unlocked?
                #:valid-and-own-or-unlocked?
                #:current-tlog
                #:with-recording-to-tlog

                #:tvar> #:try-lock-tvar #:unlock-tvar
                #:txhash-table #:make-txhash-table
                #:txhash-table-count
                #:get-txhash #:set-txhash #:do-txhash)

  (:import-from #:stmx.util
                #:_
                #:print-object-contents
                #:print-gmap
                #:gmap-node #:rbnode #:tnode #:color-of
                #:gmap/new-node
                #:+red+ #:+black+
                #:red? #:black?)

  (:export #:suite))


(in-package :stmx.test)

(fiveam:def-suite suite)

(defun configure-log4cl ()
  (log:config :clear :sane :this-console ;; :daily "log.txt"
              :pattern "%D{%H:%M:%S} %-5p  <%c{}{}{:downcase}> {%t} %m%n")
  (log:config :info))
