; ACL2 Version 6.3 -- A Computational Logic for Applicative Common Lisp
; Copyright (C) 2013, Regents of the University of Texas

; This version of ACL2 is a descendent of ACL2 Version 1.9, Copyright
; (C) 1997 Computational Logic, Inc.  See the documentation topic NOTES-2-0.

; This program is free software; you can redistribute it and/or modify
; it under the terms of Version 2 of the GNU General Public License as
; published by the Free Software Foundation.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

; Written by:  Matt Kaufmann               and J Strother Moore
; email:       Kaufmann@cs.utexas.edu      and Moore@cs.utexas.edu
; Department of Computer Sciences
; University of Texas at Austin
; Austin, TX 78712-1188 U.S.A.

; This file contains code for browsing ACL2 community book
; system/doc/acl2-doc.lisp, which contains the ACL2 system
; documentation.

; The first two forms are copied from emacs-acl2.el.  Keep them in
; sync with the definitions there.

(defvar *acl2-sources-dir*)

; Attempt to set *acl2-sources-dir*.
; WARNING: If you change this form, then also change the same form in
; emacs-acl2.el.
(if (and (not (boundp '*acl2-sources-dir*))
         (file-name-absolute-p load-file-name))
    (let ((pattern (if (string-match "[\\]" load-file-name)
                       "\[^\\]+\\*$"
                     "/[^/]+/*$"))
          (dir (file-name-directory load-file-name)))
      (let ((posn (string-match pattern dir)))
        (if posn
            (setq *acl2-sources-dir*
                  (substring dir 0 (1+ posn)))))))

(defun acl2-doc-fix-alist (alist)

;;; We delete topics whose names start with a vertical bar.  Most of
;;; these are for the tours anyhow.  We also lose release notes topics
;;; for ACL2(r) from July 2011 and before, but that seems minor
;;; compared to the pain of dealing with these topics, since Emacs
;;; Lisp doesn't seem to use |..| for escaping.

  (let ((ans nil))
    (while alist
      (let* ((entry (pop alist))
             (sym (car entry)))
        (if (and (symbolp sym)          ; always true?
                 (not (equal (aref (symbol-name sym) 0) ?|)))
            (push entry ans))))
    (reverse ans)))

; We introduce variables in acl2-doc-init-vars below, but for now we
; declare *acl2-doc-file* since it is used in acl2-doc-alist (though
; probably this isn't necessary).
(defvar *acl2-doc-file*)

(defun acl2-doc-alist ()
  (let ((buf (find-file-noselect *acl2-doc-file*)))
    (with-current-buffer
        buf
      (save-excursion
        (lisp-mode)
        (goto-char (point-min))
        (forward-sexp 1)
        (forward-line 3)
        (prog1 (acl2-doc-fix-alist (read buf))
          (message "%s" "Refreshed ACL2-Doc history"))))))

(defmacro defv (var form)
  `(progn (defvar ,var)
	  (setq ,var ,form)))

(defmacro acl2-doc-init-vars ()
  '(progn
     (defv *acl2-doc-file*
       (concat *acl2-sources-dir* "doc.lisp"))
     (defv *acl2-doc-alist*
       (acl2-doc-alist))
     (defv *acl2-doc-buffer-name*
       "acl2-doc")
     (defv *acl2-doc-index-buffer-name*
       "acl2-doc-index")
     (defv *acl2-doc-index-name* nil)
     (defv *acl2-doc-index-name-found-p* nil)
     (defv *acl2-doc-search-buffer-name*
       "acl2-doc-search")
     (defv *acl2-doc-search-string* nil)
     (defv *acl2-doc-search-regexp-p* nil)
     (defv *acl2-doc-search-separator* "###---###---###---###---###")
     (defv *acl2-doc-history* nil)
     (defv *acl2-doc-return* nil)))

(acl2-doc-init-vars)

(defun acl2-doc-reset ()
  (when (get-buffer *acl2-doc-index-buffer-name*)
    (kill-buffer *acl2-doc-index-buffer-name*))
  (when (get-buffer *acl2-doc-search-buffer-name*)
    (kill-buffer *acl2-doc-search-buffer-name*))
  (acl2-doc-init-vars))

(define-derived-mode acl2-doc-mode
  fundamental-mode
  "ACL2-Doc"
  "Major mode for acl2-doc buffer."

; By using lisp-mode-syntax-tablee, we arrange that the use of colon
; (:) doesn't break up an s-expression.  So for example,
; ACL2-PC::REWRITE is a single s-expression.  This matters because we
; define the function acl2-doc-topic-at-point in terms of
; backward-sexp.  Of course, we could instead evaluate the form
; (modify-syntax-entry ?: "w" acl2-doc-mode-syntax-table) but we start
; this way, in case other characters are missing and also because this
; approach might conceivably be useful for people who are navigating
; lisp forms in the acl2-doc buffer.

; Warning: If you change the value for :syntax-table, consider the
; effect on the use of lisp-mode in function acl2-doc-index.

  :syntax-table lisp-mode-syntax-table)

(defun switch-to-acl2-doc-buffer ()
  (prog1 (switch-to-buffer *acl2-doc-buffer-name*)
    (acl2-doc-mode)))

(defun acl2-doc-print-topic (tuple)
  (insert (format "Topic: %s\nParent list: %s\n\n%s\n"
                  (nth 0 tuple)
                  (nth 1 tuple)
                  (nth 2 tuple))))

(defun acl2-doc-display-basic (entry)

; Entry is a history entry, hence of the form (point name parents string).

; The first form below is unnecessary if the caller is
; acl2-doc-display, but it's cheap.

  (switch-to-acl2-doc-buffer)
  (setq buffer-read-only nil)
  (erase-buffer)
  (acl2-doc-print-topic (cdr entry)) ; entry is (cons position tuple)
  (setq buffer-read-only t)
  (goto-char (nth 0 entry)))

(defun acl2-doc-display (name)

;;; Name should be a symbol.  We display the topic and adjust the
;;; history and return history.  Do not use this for the "l" or "r"
;;; commands; use acl2-doc-display-basic instead, which does not mess
;;; with those history variables.

  (let ((tuple (assoc name *acl2-doc-alist*)))
    (cond (tuple (switch-to-acl2-doc-buffer)
                 (let ((new-entry (cons 0 tuple)))
                   (if *acl2-doc-history*
                       (let ((old-entry (pop *acl2-doc-history*)))
                         (push (cons (point) (cdr old-entry))
                               *acl2-doc-history*)))
                   (push new-entry *acl2-doc-history*)
		   (setq *acl2-doc-return* nil)
                   (acl2-doc-display-basic new-entry)))
          (t (error "Not found: %s" name)))))

(defun acl2-doc-topic-at-point ()

;;; This function returns nil if the s-expression at point isn't a
;;; symbol.  Otherwise, it returns that symbol in upper case, except
;;; that it removes the leading and trailing bracket for [...].

  (let ((sym (sexp-at-point))
	(go t))
    (while go
      (cond ((and (consp sym)
		  (equal (length sym) 2)
		  (member (car sym)
			  '(\` quote)))
	     (setq sym (car (cdr sym))))
	    (t (setq go nil))))
    (let* ((sym (or sym

;;; We have found that (sexp-at-point) returns nil when standing in
;;; text that ends in a square bracket followed by a period, e.g.,
;;; "[loop-stopper]."  So we try again.

		    (save-excursion
		      (if (< (point) (point-max))
			  (forward-char 1)) ; in case we are at "["
		      (let* ((saved-point (point))
			     (start (and (re-search-backward "[^]]*[[]" nil t)
					 (match-beginning 0))))
			(and start
			     (let ((end (and (re-search-forward "[^ ]*]" nil t)
					     (match-end 0))))
			       (and end
				    (<= saved-point end)
				    (goto-char (1+ start))
				    (read (current-buffer))))))))))
      (cond ((arrayp sym) ;; [...]
	     (let ((sym (aref sym 0)))
	       (and (symbolp sym)
		    (intern (upcase (symbol-name sym))))))
	    ((not (and sym (symbolp sym)))
	     nil)
	    (t
	     (let* ((name (symbol-name sym))
		    (max-orig (1- (length name)))
		    (max max-orig)
		    (name (cond ((equal (aref name 0) ?:)
				 (setq max (1- max))
				 (substring 1 name))
				(t name)))
		    (go t))
	       (while (and go (< 1 max))
		 (cond ((member (aref name max)
				'(?. ?\' ?:))
			(setq max (1- max)))
		       (t (setq go nil))))
	       (intern (upcase (cond ((equal max max-orig)
				      name)
				     (t (substring name 0 (1+ max))))))))))))

(defun acl2-doc-completing-read (prompt silent-error-p)
  (let* ((completion-ignore-case t)
         (default (acl2-doc-topic-at-point))
         (default (and (assoc default *acl2-doc-alist*)
                       default))
         (value-read (completing-read
                      (if default
                          (format "%s (default %s): " prompt default)
                        (format "%s: " prompt))
                      *acl2-doc-alist*
                      nil nil nil nil
                      default)))
    (list (cond ((equal value-read default) ;; i.e., (symbolp value-read)
                 default)
                ((and (not silent-error-p)
                      (equal value-read ""))
                 (error "No default topic name found at point"))
                (t (intern (upcase value-read)))))))

(defun acl2-doc-go (name)
  "Go to the specified topic; performs completion."
  (interactive (acl2-doc-completing-read "Go to topic" nil))
  (acl2-doc-display name))

(defun acl2-doc-go! ()
  "Go to the topic occurring at the cursor position."
  (interactive)
  (let ((name (acl2-doc-topic-at-point)))
    (cond (name (acl2-doc-display name))
	  (t (error "Cursor is not on a name")))))

(defun acl2-doc (&optional clear)
  "Start or return to the ACL2-Doc browser; prefix argument clears state.
\\{acl2-doc-mode-map}"
  (interactive "P")
  (cond (clear
         (acl2-doc-reset)
         (acl2-doc-go 'ACL2))
        (*acl2-doc-history*
         (acl2-doc-display-basic (car *acl2-doc-history*)))
        (t
         (acl2-doc-go 'ACL2))))

(defun acl2-doc-last ()
  "Go to the last topic visited."
  (interactive)
  (cond ((cdr *acl2-doc-history*)
         (push (pop *acl2-doc-history*)
	       *acl2-doc-return*)
         (acl2-doc-display-basic (car *acl2-doc-history*)))
        (t (error "No last page visited"))))

(defun acl2-doc-return ()
  "Return to the last topic visited, popping the stack of such topics."
  (interactive)
  (cond (*acl2-doc-return*
	 (let ((entry (pop *acl2-doc-return*)))
	   (push entry *acl2-doc-history*)
	   (acl2-doc-display-basic entry)))
        (t (error "Nothing to return to"))))

(defun acl2-doc-up ()
  "Go to the parent of the current topic."
  (interactive)
  (switch-to-acl2-doc-buffer)
  (let ((first-parent
         (save-excursion
           (goto-char (point-min))
           (search-forward "Parent list: (")
           (acl2-doc-topic-at-point))))
    (if (equal first-parent 'TOP)
        (error "Already at the root node of the ACL2 manual")
      (acl2-doc-display first-parent))))

(defun acl2-doc-update-top-history-entry ()
  (cond ((null *acl2-doc-history*)
	 (error "Empty history!"))
	(t (with-current-buffer
	       *acl2-doc-buffer-name* ; error if this was killed!
	     (setq *acl2-doc-history*
		   (cons (cons (point) (cdr (car *acl2-doc-history*)))
			 (cdr *acl2-doc-history*)))))))

(defun acl2-doc-quit ()
  "Quit the ACL2-Doc browser."
  (interactive)
  (switch-to-acl2-doc-buffer)
  (acl2-doc-update-top-history-entry)
  (quit-window))

(defun acl2-doc-top ()
  "Go to the top topic."
  (interactive)
  (acl2-doc-go 'ACL2))

(defun acl2-doc-initialize ()
  "Restart the ACL2-Doc browser, clearing its state."
  (interactive)
  (acl2-doc-reset)
  (acl2-doc-top))

(defun acl2-doc-index-buffer ()
  (or (get-buffer *acl2-doc-index-buffer-name*)
      (let ((buf (get-buffer-create *acl2-doc-index-buffer-name*))
            (alist *acl2-doc-alist*))
	(with-current-buffer
	    buf
          (while alist
            (insert (format "%s\n" (car (pop alist))))))
	buf)))

(defun acl2-doc-read-line ()

; Return the current line, and go to the end of it.

  (forward-line 0)
  (let ((beg (point)))
    (end-of-line)
    (buffer-substring beg (point))))

(defun acl2-doc-index (name)
  "Go to the specified topic or else one containing it as a substring;
performs completion."
  (interactive (acl2-doc-completing-read
                "Find topic (then use \",\" for more) "
                t))
  (let ((buf (acl2-doc-index-buffer))
	(found-p (assoc name *acl2-doc-alist*)))
    (setq *acl2-doc-index-name-found-p* (consp found-p))
    (setq *acl2-doc-index-name* (symbol-name name))
    (cond
     (found-p (with-current-buffer
		  buf
		(goto-char (point-min)))
	      (acl2-doc-display name))
     (t (let ((topic
	       (with-current-buffer
		   buf
		 (lisp-mode) ; same as for acl2-doc-mode, without key bindings
		 (goto-char (point-min))
		 (cond ((search-forward (symbol-name name) nil t)
			(intern (acl2-doc-read-line)))
		       (t (setq *acl2-doc-index-name* nil)
			  (error "No matching topic found"))))))
	  (acl2-doc-display topic))))))

(defun acl2-doc-index-next ()
  "Find the next topic containing, as a substring, the topic from the
previous i command."
  (interactive)
  (let ((buf (get-buffer *acl2-doc-index-buffer-name*)))
    (when (null buf)
      (error "Need to initiate index search"))
    (let ((topic (with-current-buffer
		     buf
		   (and (search-forward *acl2-doc-index-name* nil t)
			(acl2-doc-read-line)))))
      (cond (topic
	     (cond ((and *acl2-doc-index-name-found-p*
			 (equal topic *acl2-doc-index-name*))
		    (setq *acl2-doc-index-name-found-p* nil)
		    (acl2-doc-index-next))
		   (t (acl2-doc-display (intern topic)))))
	    (t (with-current-buffer
		   buf
		 (goto-char (point-min)))
	       (error
		"No more matches; try again to start from the beginning"))))))

(defun acl2-doc-search-buffer ()
  (or (get-buffer *acl2-doc-search-buffer-name*)
      (let ((buf (get-buffer-create *acl2-doc-search-buffer-name*))
            (alist *acl2-doc-alist*))
	(with-current-buffer
	    buf
          (while alist
	    (insert "\n")
	    (insert *acl2-doc-search-separator*)
	    (insert "\n")
	    (acl2-doc-print-topic (pop alist)))
	  (setq buffer-read-only t))
	buf)))

(defun acl2-doc-search (str &optional regexp-p)
  "Search forward from the top of the manual for a given string.
If no input is supplied (i.e. <RETURN> is entered at the prompt),
then search forward from the end of the previous search, using a
regular expression search if the previous search was done that way.
Otherwise, if a prefix argument is supplied, do a regular expression search.
In each case, the topic is displayed in which the text is found,
with the cursor immediately after the text, and with the topic name
displayed in the minibuffer."

  (interactive "sSearch: 
P")

  (let* ((buf (acl2-doc-search-buffer))
	 (continue-p (equal str ""))
	 (pair
	  (with-current-buffer
	      buf
	    (cond
	     (continue-p
	      (cond
	       (*acl2-doc-search-string*
		(setq regexp-p *acl2-doc-search-regexp-p*)
		(setq str *acl2-doc-search-string*))
	       (t (error "No search has been done, so none to continue"))))
	     (t
	      (goto-char (point-min))))
	    (cond
	     ((if regexp-p
		  (re-search-forward str nil t)
		(search-forward str nil t))
	      (save-excursion
		(let ((point-found (match-end 0)))
		  (search-backward *acl2-doc-search-separator*)
		  (forward-line 1)
		  (let ((point-start (point)))
		    (cons (1+ (- point-found point-start)) ; (point-min) = 1
			  (let ((beg (+ point-start 7)))   ;"Topic: "
			    (end-of-line)
			    (buffer-substring beg (point))))))))
	     (t nil)))))
    (cond (pair
; The first two assignments are redundant if continue-p is true.
	   (setq *acl2-doc-search-string* str)
	   (setq *acl2-doc-search-regexp-p* regexp-p)
	   (acl2-doc-display (intern (cdr pair)))
	   (message "Topic: %s" (cdr pair))
	   (goto-char (car pair))
	   (acl2-doc-update-top-history-entry))
	  (continue-p (with-current-buffer
			  buf
			(goto-char (point-min)))
		      (error "Try again for wrapped search"))
	  (t (error "Not found: %s" str)))))

(defun acl2-doc-search! ()
  "Find next occurrence, using regexp search if and only if it was used when
in the original corresponding search."

  (interactive)
  (acl2-doc-search ""))

(define-key global-map "\C-Xaa" 'acl2-doc)
(define-key global-map "\C-XaA" 'acl2-doc-initialize)

(define-key acl2-doc-mode-map "g" 'acl2-doc-go)
(define-key acl2-doc-mode-map "\C-M" 'acl2-doc-go!)
(define-key acl2-doc-mode-map "i" 'acl2-doc-index)
(define-key acl2-doc-mode-map "," 'acl2-doc-index-next)
(define-key acl2-doc-mode-map "I" 'acl2-doc-initialize)
(define-key acl2-doc-mode-map "l" 'acl2-doc-last)
(define-key acl2-doc-mode-map "r" 'acl2-doc-return)
(define-key acl2-doc-mode-map "s" 'acl2-doc-search)
(define-key acl2-doc-mode-map "S" 'acl2-doc-search!)
(define-key acl2-doc-mode-map "t" 'acl2-doc-top)
(define-key acl2-doc-mode-map "u" 'acl2-doc-up)
(define-key acl2-doc-mode-map "q" 'acl2-doc-quit)
