STMX
======

Introduction
------------

STMX is an actively maintained, high-performance concurrency library providing
Software Transactional Memory for Common Lisp.

Home page and downloads: [http://github.com/cosmos72/stmx](http://github.com/cosmos72/stmx)

Main features
-------------

- Extremely intuitive to use and to write correct, thread-safe concurrent code.
- Brings database-style transactions to Common Lisp by introducing transactional
  memory.
- High performance implementation, benchmarked to exceed 1 million transactions
  per CPU core per second on commodity PC hardware.
- Removes the need for traditional locks, mutexes and conditions - writing
  correct concurrent code with them is well known to be hard.
- Transactional code is intrinsically deadlock-free: if two transactions
  conflict one of them will be re-executed.
- Automatic commit and rollback: if a transaction completes normally it will
  be committed, if it signals an error it will be rolled back.
- Transactions are composable: they can be executed in a larger transaction,
  either in sequence (all-or-nothing) or as alternatives (try them in order
  until one succeeds).
- Offers freedom of choice between blocking and non-blocking transactional
  functions: given either behaviour, it is trivial to transform it into the
  other.
- Features transactional versions of popular data structures: hash tables,
  red-black trees, stack, fifo, etc.
- Includes transactional data structure for multicast publish/subscribe
- Creating new transactional data structures is easy.
- Extensive test suite.
- Tested on SBCL; Porting to CCL almost completed.
- Very simple to install with [Quicklisp](http://www.quicklisp.org/).

A quick-start guide and installation instructions are provided in the file
[README.md](../README.md).

License: [LLGPL](http://opensource.franz.com/preamble.html)

What STMX is NOT
----------------

In order not to confuse programmers - less experienced ones in particular -
and to avoid rising unrealistic hopes, the author states the following
about STMX:

- it is NOT a quick hack to automagically transform existing, slow,
  single-threaded programs into fast, concurrent ones.
  No matter how much transactions can help, writing concurrent code
  still requires careful design and implementation - and testing.
  And refactoring takes time too.
- it is NOT for optimization-focused programmers trying to squeeze the last
  cycle from their Common Lisp programs. STMX records an in-memory transaction
  log containing all reads and writes from/to transactional memory, then later
  (during commit) validates the transaction log against the latest data present
  in transactional memory and finally copies the transaction log onto the
  transactional memory while holding locks. STMX is quite optimized, but this
  machinery comes at an obvious performance cost with respect to hand-made,
  highly optimized locking code (but a good reality check is to ask yourself
  how many people have the skill and patience to write such code without bugs).
- it is NOT supposed to be used for all data structures in a Common Lisp
  program. STMX is intended only for the data accessed concurrently by multiple
  threads while being modified by at least one thread. And even in that case,
  transactional memory is **not always** needed: it depends on the kinds of
  modifications.
- it is NOT a serialization or persistence framework. Rather, messing with
  metaclasses and playing (allowed) tricks with slots contents as STMX does,
  quite likely does **not** mix well with serialization or persistence
  libraries such as CL-STORE, because they typically need full control on the
  slots of the objects to be serialized and de-serialized.
- it is NOT a million dollar library from some deep-pocket company. At the
  moment, it is the work of a single person.


Implementation
--------------

STMX is based on the concepts described in [Composable Memory
Transactions](http://research.microsoft.com/~simonpj/papers/stm/stm.pdf)
with the addition of a global version clock as described in [Transactional
Locking II](http://home.comcast.net/~pjbishop/Dave/GVTL-TL2-Disc06-060711-Camera.pdf)

In particular:
- transactional memory reads and writes are stored in a transaction log,
  and written values are copied into the actual memory location only during
  commit
- each transactional memory location is locked only during commit, not while
  accessing it
- conflicts, i.e. multiple transactions trying to write simultaneously
  the same  memory location, are detected automatically during commit.
  In such case, one transaction will commit and all other ones will be
  re-executed
- thanks to the global version clock, it *cannot* happen that a transaction
  sees an inconsistent view of transactional memory.
  
  The worst that can happen is an automatic re-execution of a
  transaction immediately *before* it can see an inconsistent view of
  transactional memory.