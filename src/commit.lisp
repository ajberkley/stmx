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


(in-package :stmx)

;;;; ** Validating


(defun valid? (log)
  "Return t if a TLOG is valid, i.e. it contains an up-to-date view
of TVARs that were read during the transaction."
  (declare (type tlog log))

  (log.trace "Tlog ~A valid?.." (~ log))
  (let1 tlog-version (tlog-id log)
    (do-hash (var) (tlog-reads log)
      (if (<= (the fixnum (tvar-version var)) (the fixnum tlog-version))
          (log.trace "Tlog ~A tvar ~A is up-to-date" (~ log) (~ var))
          (progn
            (log.trace "Tlog ~A conflict for tvar ~A: expecting version <= ~A, found version ~A"
                       (~ log) (~ var) tlog-version (tvar-version var))
            (log.debug "Tlog ~A ..not valid" (~ log))
            (return-from valid? nil)))))
  (log.trace "Tlog ~A ..is valid" (~ log))
  t)



(defun invalid-or-locked? (log)
  "Return T if LOG is invalid, or if TVARs read during transaction are currently
locked by some other thread (being locked by current thread does not count)."
  (declare (type tlog log))

  (log.trace "Tlog ~A invalid-or-locked?.." (~ log))
  (let1 tlog-version (tlog-id log)
    (do-hash (var) (tlog-reads log)
      (if (<= (the fixnum (tvar-version var)) (the fixnum tlog-version))
          (progn
            (log.trace "Tlog ~A tvar ~A is up-to-date" (~ log) (~ var))
            (when (tvar-is-locked-by-other-thread? var log)
              (log.debug "Tlog ~A tvar ~A is locked by another thread" (~ log) (~ var))
              (return-from invalid-or-locked? t)))

          (progn
            (log.trace "Tlog ~A conflict for tvar ~A: expecting <= version ~A, found version ~A"
                       (~ log) (~ var) tlog-version (tvar-version var))
            (log.debug "Tlog ~A ..not valid" (~ log))
            (return-from invalid-or-locked? t)))))
  (log.trace "Tlog ~A ..is valid and not locked" (~ log))
  nil)


(declaim (inline invalid? shallow-valid? shallow-invalid?))

(defun invalid? (log)
  "Return (not (valid? LOG))."
  (declare (type tlog log))
  (not (valid? log)))






(defun shallow-valid? (log)
  "Return T if a TLOG is valid. Similar to (valid? log),
but does *not* check log parents for validity."
  (declare (type tlog log))
  ;; current implementation always performs a deep validation
  (valid? log))
  

(declaim (inline shallow-invalid?))
(defun shallow-invalid? (log)
  "Return (not (shallow-valid? LOG))."
  (declare (type tlog log))
  (not (shallow-valid? log)))


(defun tvar> (var1 var2)
  (declare (type tvar var1 var2))
  "Compare var1 and var2 with respect to age: newer tvars usually have larger
tvar-id and are considered \"larger\". Returns (> (tvar-id var1) (tvar-id var2))."
  (> (the fixnum (tvar-id var1))
     (the fixnum (tvar-id var2)))
  #+never
  (< (the fixnum (sb-impl::get-lisp-obj-address var1))
     (the fixnum (sb-impl::get-lisp-obj-address var2)))
  #+never
  (< (the fixnum (sxhash var1))
     (the fixnum (sxhash var2))))






(defun try-lock-tvars (vars locked-vars)
  "Sort VARS in order - actually in (tvar< ...) order -
then non-blocking acquire their locks in such order.
Reason: acquiring in unspecified order may cause livelock, as two transactions
may repeatedly try acquiring the same two TVARs in opposite order.

LOCKED-VARS must be the one-element list '(nil).
Destructively modifies VARS and LOCKED-VARS.

Return t if all VARS where locked successfully, otherwise return nil.
In both cases, after this call (rest LOCKED-VARS) will be the list
containing the locked tvars, sorted in order from first acquired
to last acquired."
  (declare (type list vars locked-vars))
  #+never (log:user5 "unsorted TVARs to lock: (~{~A~^ ~})" vars)
  ;;(setf vars (sort vars #'tvar>))
  #+never (log:user5 "  sorted TVARs to lock: (~{~A~^ ~})" vars)

  (loop for cell = vars then rest
     while cell
     for rest = (rest cell)
     always (try-lock-tvar (first cell))
     do (setf (rest locked-vars) cell)
       (setf locked-vars cell)
       (setf (rest cell) nil)
     finally (return t)))


(declaim (inline unlock-tvars))
(defun unlock-tvars (vars)
  "Release locked (rest VARS) in same order of acquisition."
  (declare (type list vars))
  (loop for var in (rest vars) do
       (unlock-tvar var)))


(declaim (inline locked-valid?))
(defun locked-valid? (log)
  "Return T if LOG is valid and NIL if it's invalid.
Return :UNKNOWN if relevant locks could not be acquired.

Thanks to the global versioning of transactions, this method
does not need to acquire locks."
  (declare (type tlog log))
  (valid? log))



;;;; ** Committing


(defun ensure-tlog-before-commit (log)
  "Create tlog-before-commit log if nil, and return it."
  (declare (type tlog log))
  (the vector
    (or (tlog-before-commit log)
        (setf (tlog-before-commit log)
              (make-array '(1) :element-type 'function :fill-pointer 0 :adjustable t)))))

(defun ensure-tlog-after-commit (log)
  "Create tlog-after-commit log if nil, and return it."
  (declare (type tlog log))
  (the vector
    (or (tlog-after-commit log)
        (setf (tlog-after-commit log)
              (make-array '(1) :element-type 'function :fill-pointer 0 :adjustable t)))))




(defun call-before-commit (func &optional (log (current-tlog)))
  "Register FUNC function to be invoked immediately before the current transaction commits.

IMPORTANT: See BEFORE-COMMIT for what FUNC must not do."
  (declare (type function func)
           (type tlog log))
  (vector-push-extend func (ensure-tlog-before-commit log))
  func)

(defun call-after-commit (func &optional (log (current-tlog)))
  "Register FUNC function to be invoked after the current transaction commits.

IMPORTANT: See AFTER-COMMIT for what FUNC must not do."
  (declare (type function func)
           (type tlog log))
  (vector-push-extend func (ensure-tlog-after-commit log))
  func)



(defmacro before-commit (&body body)
  "Register BODY to be invoked immediately before the current transaction commits.
If BODY signals an error when executed, the error is propagated to the caller,
further code registered with BEFORE-COMMIT are not executed,
and the transaction rollbacks.

BODY can read and write normally to transactional memory, and in case of conflicts
the whole transaction (not only the code registered with before-commit)
is re-executed from the beginning.

WARNING: BODY cannot (retry) - attempts to do so will signal an error.
Starting a nested transaction and retrying inside that is acceptable,
as long as the (retry) does not propagate outside BODY."
  `(call-before-commit (lambda () ,@body)))


(defmacro after-commit (&body body)
  "Register BODY to be invoked after the current transaction commits.
If BODY signals an error when executed, the error is propagated
to the caller and further code registered with AFTER-COMMIT is not executed,
but the transaction remains committed.

WARNING: Code registered with after-commit has a number or restrictions:

1) BODY must not write to *any* transactional memory: the consequences
are undefined.

2) BODY can only read from transactional memory already read or written
during the same transaction. Reading from other transactional memory
has undefined consequences.

3) BODY cannot (retry) - attempts to do so will signal an error.
Starting a nested transaction and retrying inside that is acceptable
as long as the (retry) does not propagate outside BODY."
  `(call-after-commit (lambda () ,@body)))



(defun loop-funcall-on-appendable-vector (funcs)
  "Call each function in FUNCS vector. Take care that functions being invoked
can register other functions - or themselves again - with (before-commit ...)
or with (after-commit ...).
This means new elements can be appended to FUNCS vector during the loop
=> (loop for func across funcs ...) is not enough."
  (declare (type vector funcs))
  (loop for i from 0
     while (< i (length funcs))
     do
       (funcall (aref funcs i))))


(defun invoke-before-commit (log)
  "Before committing, call in order all functions registered
with (before-commit)
If any of them signals an error, the transaction will rollback
and the error will be propagated to the caller"
  (declare (type tlog log))
  (when-bind funcs (tlog-before-commit log)
    ;; restore recording and log as the current tlog, functions may need them
    ;; to read and write transactional memory
    (with-recording-to-tlog log
      (handler-case
          (loop-funcall-on-appendable-vector funcs)
        (rerun-error ()
          (log.trace "Tlog ~A before-commit wants to rerun" (~ log))
          (return-from invoke-before-commit nil)))))
  t)


(defun invoke-after-commit (log)
  "After committing, call in order all functions registered with (after-commit)
If any of them signals an error, it will be propagated to the caller
but the TLOG will remain committed."
  (declare (type tlog log))
  (when-bind funcs (tlog-after-commit log)
    ;; restore recording and log as the current tlog, functions may need them
    ;; to read transactional memory
    (with-recording-to-tlog log
      (loop-funcall-on-appendable-vector funcs)))
  t)


(defun commit (log)
  "Commit a TLOG to memory.

It returns a boolean specifying whether or not the transaction
log was committed.  If the transaction log cannot be committed
it either means that:
a) the TLOG is invalid - then the whole transaction must be re-executed
b) another TLOG is writing the same TVARs being committed
   so that TVARs locks could not be aquired - also in this case
   the whole transaction will be re-executed, as there is little hope
   that the TLOG will still be valid."
   
  (declare (type tlog log))
  (let ((writes   (tlog-writes log))
        (new-version +invalid-counter+)
        (acquiring nil)
        (acquired (list nil))
        (changed   nil)
        (success   nil))

    (declare (type list acquiring acquired changed)
             (type fixnum new-version)
             (type boolean success))

    ;; before-commit functions run without locks
    (unless (invoke-before-commit log)
      (return-from commit nil))

    (when (zerop (hash-table-count writes))
      (log.debug "Tlog ~A committed (nothing to write)" (~ log))
      (invoke-after-commit log)
      (return-from commit t))

    (unwind-protect
         (block nil
           ;; we must lock TVARs that have been written: expensive
           ;; but needed to ensure concurrent commits do not conflict.
           (setf acquiring (hash-table-keys writes))
           (unless (try-lock-tvars acquiring acquired)
             (log.debug "Tlog ~A failed to lock tvars, not committed" (~ log))
             (return))
           
           (log.trace "Tlog ~A acquired locks..." (~ log))

           (setf new-version (incf-atomic-counter *tlog-counter*))

           ;; if new-version is (1+ read-version), no need to validate anything
           (unless (= new-version (the fixnum (1+ (tlog-id log))))
             ;; check for log validity one last time, with locks held.
             ;; this time we also check that reads are NOT locked by other threads
             (when (invalid-or-locked? log)
               (log.debug "Tlog ~A is invalid or reads are locked, not committed" (~ log))
               (return)))

           (log.trace "Tlog ~A committing..." (~ log))

           ;; COMMIT, i.e. actually write new values into TVARs
           (do-hash (var val) writes
             (let1 current-val (raw-value-of var)
               (when (not (eq val current-val))
                 (setf (tvar-versioned-value var) (cons new-version val))
                 (push var changed)
                 (log.trace "Tlog ~A tvar ~A changed value from ~A to ~A"
                            (~ log) (~ var) current-val val))))

           (log.debug "Tlog ~A ...committed" (~ log))
           (setf success t))

      (unlock-tvars acquired)
      (log.trace "Tlog ~A ...released locks" (~ log))
      
      (dolist (var changed)
        (log.trace "Tlog ~A notifying threads waiting on tvar ~A"
                   (~ log) (~ var))
        (notify-tvar-high-load var))
          
      (when success
        ;; after-commit functions run without locks
        (invoke-after-commit log)))

    success))
                   



;;;; ** Merging


(defun merge-tlog-reads (log1 log2)
  "Merge (tlog-reads LOG1) and (tlog-reads LOG2).

Return merged TLOG (either LOG1 or LOG2) if tlog-reads LOG1 and LOG2 are compatible,
i.e. if they contain the same values for the TVARs common to both, otherwise return NIL
\(in the latter case, the merge will not be completed)."
  (declare (type tlog log1 log2))
  (let* ((reads1 (tlog-reads log1))
         (reads2 (tlog-reads log2))
         (n1 (hash-table-count reads1))
         (n2 (hash-table-count reads2)))
         
    (when (< n1 n2)
      (rotatef log1 log2)
      (rotatef reads1 reads2)
      (rotatef n1 n2)) ;; guarantees n1 >= n2

    (if (or (zerop n2) (merge-hash-tables reads1 reads2))
        log1
        nil)))

  


(defun commit-nested (log)
  "Commit LOG into its parent log; return LOG.

Unlike (commit log), this function is guaranteed to always succeed.

Implementation note: copy tlog-reads, tlog-writes, tlog-before-commit
and tlog-after-commit into parent, or swap them with parent"

  (declare (type tlog log))
  (let1 parent (the tlog (tlog-parent log))

    (rotatef (tlog-reads parent) (tlog-reads log))
    (rotatef (tlog-writes parent) (tlog-writes log))

    (when-bind funcs (tlog-before-commit log)
      (if-bind parent-funcs (tlog-before-commit parent)
        (loop for func across funcs do
             (vector-push-extend func parent-funcs))
        (rotatef (tlog-before-commit log) (tlog-before-commit parent))))

    (when-bind funcs (tlog-after-commit log)
      (if-bind parent-funcs (tlog-after-commit parent)
        (loop for func across funcs do
             (vector-push-extend func parent-funcs))
        (rotatef (tlog-after-commit log) (tlog-after-commit parent))))

    log))

