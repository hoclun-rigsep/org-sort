#!/usr/bin/env emacs -Q --script
;; org-sort-top-level.el — stdin -> sort top-level headings -> stdout
;;
;; Usage (primary key first):
;;   emacs --batch -Q --script org-sort-top-level.el -- --key=t --key=a  < in.org > out.org
;;   emacs --batch -Q --script org-sort-top-level.el -- --key=A         < in.org > out.org
;;   emacs --batch -Q --script org-sort-top-level.el -- -k pA < in.org > out.org
;;
;; Keys (uppercase reverses sort order):
;;   a  alphabetical (headline text)
;;   n  numeric within headline
;;   o  TODO keyword order
;;   p  priority cookie
;;   s  SCHEDULED timestamp
;;   d  DEADLINE timestamp
;;   t  other timestamp in headline

(let* ((args command-line-args-left)
       (keys '()))

  ;; Parse flags after `--`
  (while args
    (let ((a (pop args)))
      (cond
       ((string-match "^--key=\\(.+\\)$" a)
        (push (match-string 1 a) keys))
       ((string= a "-k")
        (when args (push (pop args) keys)))
       ((member a '("-h" "--help"))
          (princ "Usage: emacs --batch -Q --script org-sort-top-level.el -- [--key=CODES]\n  CODES: sequence of sort codes, e.g. Oa (primary first)\n  Codes: a/A alpha, n/N numeric, o/O TODO-order, t/T timestamp, p/P priority, s/S scheduled, d/D deadline\n")
        (kill-emacs 0)))))

  (setq keys (nreverse keys))            ;; preserve user order
  ;; NEW: explode combined codes, e.g. "oa" => ("o" "a"), "Oa" => ("O" "a")
  (setq keys
        (apply #'append
               (mapcar (lambda (s)
                         (mapcar (lambda (c) (char-to-string c))
                                 (string-to-list s)))
                       keys)))
  (when (null keys) (setq keys '("a")))  ;; default alpha

  (defun org-sort-top-level--spec->code (spec)
  "SPEC is a single-letter string like \"a\" or \"A\".
Lowercase = normal, uppercase = reverse."
  (let ((ch (string-to-char spec)))
    (pcase (downcase ch)
      (?a ch) (?n ch) (?o ch) (?t ch) (?p ch) (?s ch) (?d ch)
      (_ ?a))))

  (require 'org)
  (with-temp-buffer
    (insert "#+TODO: TODO INPROGRESS NEEDSREVIEW WAITING HOLD SOMEDAY | DONE CANCELLED\n")
    (insert-file-contents "/dev/stdin")
    (org-mode) 
    (let ((case-fold-search t))           ;; make alpha sort case-insensitive
      (goto-char (point-min))
      (when (re-search-forward org-heading-regexp nil t)
        (goto-char (match-beginning 0))   ;; first top-level heading
        (push-mark (point-max) t t)       ;; region: first heading -> EOF
        (activate-mark)
        ;; Apply keys from last to first so the first given is the primary
        (dolist (spec (reverse keys))
          (org-sort-entries nil (org-sort-top-level--spec->code spec)))
        (deactivate-mark)))
;; --- Remove the injected #+TODO line before output ---
    (goto-char (point-min))
    (when (looking-at "^#\\+TODO:") (delete-region (line-beginning-position) (1+ (line-end-position))))
    (princ (buffer-string))))
