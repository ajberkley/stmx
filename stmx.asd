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


(in-package :cl-user)

(asdf:defsystem :stmx
  :name "STMX"
  :version "1.9.0"
  :license "LLGPL"
  :author "Massimiliano Ghilardi"
  :description "Composable Transactional Memory"

  :depends-on (:log4cl
               :closer-mop
               :bordeaux-threads
               :trivial-garbage)

  :components ((:static-file "stmx.asd")

               
               (:module :sb-transaction
                :components #-(and sbcl x86-64)
                            ()
                            #+(and sbcl x86-64)
                            ((:file "package")
                             (:file "compiler"     :depends-on ("package"))
                             (:file "x86-64-insts" :depends-on ("compiler"))
                             (:file "x86-64-vm"    :depends-on ("x86-64-insts"))
                             (:file "cpuid"        :depends-on ("x86-64-vm"))
                             (:file "transaction"  :depends-on ("x86-64-vm"))))

               (:module :lang
                :components ((:file "package")
                             (:file "macro"           :depends-on ("package"))
                             (:file "features"        :depends-on ("macro"))
                             (:file "features-reader" :depends-on ("features"))
                             (:file "features-detect" :depends-on ("features-reader"))
                             (:file "thread"          :depends-on ("features-detect"))
                             (:file "hw-transactions" :depends-on ("features-detect"))
                             (:file "atomic-ops"      :depends-on ("features-detect"))
                             (:file "mutex"           :depends-on ("atomic-ops"))
                             (:file "atomic-counter"  :depends-on ("atomic-ops" "mutex"))
                             (:file "cons"            :depends-on ("thread"))
                             (:file "fast-vector"     :depends-on ("macro"))
                             (:file "hash-table"      :depends-on ("cons"))
                             (:file "print"           :depends-on ("macro"))
                             (:file "class-precedence-list" :depends-on ("macro")))
                :depends-on (:sb-transaction))

               (:module :main
                :components ((:file "package")
                             (:file "global-clock"   :depends-on ("package"))
                             (:file "tvar-fwd"       :depends-on ("global-clock"))
                             (:file "classes"        :depends-on ("tvar-fwd"))
                             (:file "txhash"         :depends-on ("classes"))
                             (:file "tlog"           :depends-on ("txhash"))
                             (:file "tvar"           :depends-on ("tlog"))
                             (:file "tclass"         :depends-on ("tvar"))
                             (:file "hw-atomic"      :depends-on ("classes"))
                             (:file "commit"         :depends-on ("tvar" "hw-atomic"))
                             (:file "sw-atomic"      :depends-on ("commit"))
                             (:file "atomic"         :depends-on ("hw-atomic" "sw-atomic"))
                             (:file "orelse"         :depends-on ("atomic")))
                :depends-on (:lang))


               (:module :util
                :components ((:file "package")
                             (:file "misc"           :depends-on ("package"))
                             (:file "print"          :depends-on ("package"))

                             (:file "container"      :depends-on ("misc"))
                             (:file "tcons"          :depends-on ("misc"))
                             (:file "tvar"           :depends-on ("container"))
                             (:file "tcell"          :depends-on ("container"))
                             (:file "tstack"         :depends-on ("container"))
                             (:file "tfifo"          :depends-on ("container" "tcons"))
                             (:file "tchannel"       :depends-on ("container" "tcons"))

			     (:file "bheap"          :depends-on ("container"))

                             (:file "gmap"           :depends-on ("misc" "print"))
                             (:file "rbmap"          :depends-on ("gmap"))
                             (:file "tmap"           :depends-on ("rbmap"))

                             (:file "simple-tvector" :depends-on ("print"))

                             (:file "ghash-table"    :depends-on ("print"))
                             (:file "thash-table"    :depends-on ("ghash-table" "simple-tvector")))
                :depends-on (:lang :main))))



(asdf:defsystem :stmx.test
  :name "STMX.TEST"
  :version "1.9.0"
  :author "Massimiliano Ghilardi"
  :license "LLGPL"
  :description "test suite for STMX"

  :depends-on (:log4cl
               :bordeaux-threads
               :fiveam
               :stmx)

  :components ((:module :test
                :components ((:file "package")
                             (:file "misc"           :depends-on ("package"))
			     (:file "hash-table"     :depends-on ("misc"))
                             (:file "txhash"         :depends-on ("hash-table"))
                             (:file "ghash-table"    :depends-on ("hash-table"))
                             (:file "thash-table"    :depends-on ("hash-table"))
                             (:file "rbmap"          :depends-on ("hash-table"))
                             (:file "atomic"         :depends-on ("package"))
                             (:file "conflict"       :depends-on ("package"))
                             (:file "on-commit"      :depends-on ("atomic"))
                             (:file "retry"          :depends-on ("package"))
                             (:file "orelse"         :depends-on ("package"))
                             (:file "tmap"           :depends-on ("rbmap" "orelse"))))))


(defmethod asdf:perform ((op asdf:test-op) (system (eql (asdf:find-system :stmx))))
  (asdf:load-system :stmx.test)
  (eval (read-from-string "(fiveam:run! 'stmx.test:suite)")))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





(asdf:defsystem :stmx-persist
  :name "STMX-PERSIST"
  :version "0.0.1"
  :license "LLGPL"
  :author "Massimiliano Ghilardi"
  :description "Persistent, Transactional Object Store"

  :depends-on (:log4cl
               :cffi
               :osicat
               :trivial-garbage)

  :components ((:static-file "stmx-persist.asd")

               (:module :persist
                :components ((:file "package")
                             (:file "mem"         :depends-on ("package"))
                             (:file "constants"   :depends-on ("mem"))
                             (:file "abi"         :depends-on ("constants"))
                             (:file "store"       :depends-on ("abi"))))))


(asdf:defsystem :stmx-persist.test
  :name "STMX-PERSIST.TEST"
  :version "0.0.1"
  :author "Massimiliano Ghilardi"
  :license "LLGPL"
  :description "test suite for STMX-PERSIST"

  :depends-on (:log4cl
               :fiveam
               :stmx-persist)

  :components ((:module :test-persist
                :components ((:file "package")
                             (:file "mem"           :depends-on ("package"))
                             (:file "abi"           :depends-on ("mem"))))))


(defmethod asdf:perform ((op asdf:test-op) (system (eql (asdf:find-system :stmx-persist))))
  (asdf:load-system :stmx-persist.test)
  (eval (read-from-string "(fiveam:run! 'stmx-persist.test:suite)")))
