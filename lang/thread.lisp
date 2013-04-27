;; -*- lisp -*-

;; This file is part of STMX.
;; Copyright (c) 2013 Massimiliano Ghilardi
;;
;; This library is free software: you can redistribute it and/or
;; modify it under the terms of the Lisp Lesser General Public License
;; (http://opensource.franz.com/preamble.html), known as the LLGPL.
;;
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty
;; of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
;; See the Lisp Lesser General Public License for more details.


(in-package :stmx.lang)


;;;; * Wrappers around Bordeaux Threads to capture the values returned by functions executed in threads

#-stmx-sane-bt.join-thread
(defstruct wrapped-thread
  (result nil)
  (thread (current-thread) :type thread))


(defun start-thread (function &key name (initial-bindings bt:*default-special-bindings*))

  #+stmx-sane-bt.join-thread
  (make-thread function :name name :initial-bindings initial-bindings)

  #-stmx-sane-bt.join-thread
  (let1 th (make-wrapped-thread)
    (setf (wrapped-thread-thread th)
          (make-thread (lambda ()
                         (setf (wrapped-thread-result th)
                               (funcall function)))
                       :name name
                       :initial-bindings initial-bindings))
    th))

#-stmx-sane-bt.join-thread
(defun wait4-thread (th)
  (declare (type wrapped-thread th))

  (join-thread (wrapped-thread-thread th))
  (wrapped-thread-result th))


#+stmx-sane-bt.join-thread
(defun wait4-thread (th)
  (declare (type thread th))
  (join-thread th))

