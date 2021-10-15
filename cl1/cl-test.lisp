#!/usr/bin/env -S sbcl --script

;; "sbcl --script" implies "--no-userinit", so load it:
(load (merge-pathnames ".sbclrc" (user-homedir-pathname)))

(require 'cl-json)
(require 'postmodern)
(use-package :postmodern)

(connect-toplevel "pkr" "pkr" "" "/run/postgresql") ; db user pwd host

(defun qa (fun &rest args)
  (let* ((q (format nil "select ok, js from ~a(~{~a~^,~})"
                    fun args))
         (res (query q :row))
         (ok (first res))
         (js (second res)))
    (let ((json:*json-identifier-name-to-lisp* #'identity)
          (json:*identifier-name-to-key*       #'identity))
      (values (if (eq :NULL ok) nil ok)
              (json:decode-json-from-string js)))))

(defun assoc-value (item alist)
  (cdr (assoc item alist :test #'equal)))

(multiple-value-bind (ok js)
    (qa "things")
  (assert (eq t ok))
  (assert (= 2 (length js)))
  (assert (string= "one" (assoc-value "name" (first js))))
  (assert (string= "2021-10-02" (assoc-value "created_at" (second js)))))

(multiple-value-bind (ok js)
    (qa "thing_get" 999)
  (assert (null ok))
  (assert (string= "not found" (assoc-value "error" js))))

(multiple-value-bind (ok js)
    (qa "thing_get" 1)
  (assert (eq t ok))
  (assert (string= "init" (assoc-value "category" js)))
  (assert (equal '("id" "name" "active" "category" "created_at")
                 (mapcar #'first js))))

(multiple-value-bind (ok js)
    (qa "thing_add" "''" "'err'")
  (assert (null ok))
  (assert (string= "new row for relation \"things\" violates check constraint \"no_name\""
                   (assoc-value "error" js))))

(multiple-value-bind (ok js)
    (qa "thing_add" "''" "'err'")
  (assert (null ok))
  (assert (string= "new row for relation \"things\" violates check constraint \"no_name\""
                   (assoc-value "error" js))))

(with-transaction (tr)
  (multiple-value-bind (ok js)
      (qa "thing_add" "'three'" "'test'")
    (assert (eq t ok))
    (assert (string= "three" (assoc-value "name" js)))
    (assert (string= "test" (assoc-value "category" js)))
    (assert (eq t (assoc-value "active" js))))
  (rollback-transaction tr))

(multiple-value-bind (ok js)
    (qa "thing_rename" 2 "'one'")
  (assert (null ok))
  (assert (string= "duplicate key value violates unique constraint \"things_name_key\""
                   (assoc-value "error" js))))

(with-transaction (tr)
  (multiple-value-bind (ok js)
      (qa "thing_rename" 2 "'deux'")
    (assert (eq t ok))
    (assert (string= "deux" (assoc-value "name" js)))
    (assert (null (assoc-value "category" js)))
    (assert (null (assoc-value "active" js))))
  (rollback-transaction tr))

(disconnect-toplevel)

(write-line "tests have passed successfully")
