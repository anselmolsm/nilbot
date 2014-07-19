(in-package #:nilbot)

(setf drakma:*header-stream* nil)
(push '("application" . "json") drakma:*text-content-types*)

(defvar *commands* (make-hash-table :test #'equal))

(defun command-p (string)
  (and (stringp string) (eql (char string 0) #\!)))

(defun command-trim (split)
  (if (or (null split) (command-p (car split)))
      split
      (command-trim (cdr split))))

(defun command-run (source args)
  (let ((sym (gethash (string-upcase (car args)) *commands*)))
    (if sym
      (funcall sym source args)
      "")))

(defun dirty-chars (c)
  (case c
    ((#\\ #\") t)
    (otherwise nil)))

(defun handle-message (source text)
  (let* ((clean-string (remove-if #'dirty-chars text))
	 (split (split-by-one-space clean-string))
         (args (command-trim split)))
    (if args
        (command-run source args)
        "")))

(defun split-by-one-space (string)
  (split-sequence:split-sequence #\Space string :remove-empty-subseqs t))

(defmacro defcommand (cmd args &rest body)
  `(progn
     (setf (gethash (string ',cmd) *commands*) ',cmd)
     (defun ,cmd ,args ,@body)))

(defcommand !whoami (source args)
  (declare (ignorable args))
  (format nil "~A" source))

(defun safe-parse-integer (str &optional (default 0))
  (let ((num (parse-integer str :junk-allowed t)))
    (if (null num)
        default
        num)))

(defcommand !sum (source args)
  (declare (ignorable source))
  (format nil "sum is ~A" (apply #'+ (mapcar #'safe-parse-integer (cdr args)))))

(defun get-day-of-week ()
  (multiple-value-bind
        (second minute hour date month year day daylight-p zone) (get-decoded-time)
    day))

(defun theme-at-s-u (day-of-week)
  (case day-of-week
    ((5 6) "closed?")
    (0 "no theme")
    (1 "arabian")
    (2 "feijoada")
    (3 "asian")
    (4 "mexican")))

(defcommand !s-u (source args)
  (declare (ignorable source args))
  (format nil "today's theme at s-u is ~A" (theme-at-s-u (get-day-of-week))))

(defcommand !dance (source args)
  (declare (ignorable source args))
  "<(*.*<) (^*.*^) (>*.*)>")

(defcommand !help (source args)
  (declare (ignorable source args))
  (let ((acc nil))
    (maphash #'(lambda (key value) (push (string-downcase key) acc)) *commands*)
    (format nil "~{~A~^, ~}" acc)))

(defcommand !oka (source args)
  (declare (ignorable source args))
  "valeu")

(defun get-result-from-team (team)
  (cons (cdr (assoc :country team)) (cdr (assoc :goals team))))

(defun get-matches-results (matches)
  (let ((result nil))
    (dolist (match matches result)
      (let ((home (get-result-from-team (cdr (assoc :home--team match))))
	    (away (get-result-from-team (cdr (assoc :away--team match)))))
	(push (format nil "~A ~A x ~A ~A" (car home) (cdr home) (cdr away) (car away))
	      result)))))

(defun worldcup-today-to-json ()
  (json:decode-json-from-string
   (drakma:http-request "http://worldcup.sfg.io/matches/today")))

(defcommand !worldcup (source args)
  (declare (ignorable source args))
    (format nil "today's results: ~{~A~^, ~}" (get-matches-results (worldcup-today-to-json))))

(defcommand !copa (source args)
  (declare (ignorable source args))
  "tem bolo")

(defun nasdaq-quote (code)
  (let ((request (format nil "http://finance.google.com/finance/info?client=ig\&q=~A:NASDAQ" code)))
    (multiple-value-bind (body result-code)
	(drakma:http-request request)
      (if (= (length body) 0)
	  nil
	  (subseq body 5 (- (length body) 2))))))

(defun results-from-quote (quote)
  (let ((json (json:decode-json-from-string quote)))
    (values (cdr (assoc :l--cur json)) (cdr (assoc :c json)))))

(defcommand !nasdaq (source args)
  (declare (ignorable source))
  (if (> (length args) 1)
      (let* ((code (string-upcase (second args)))
	     (result (nasdaq-quote code)))
	(if (null result)
	    (format nil "Invalid NASDAQ code (~A)" code)
	    (multiple-value-bind (cur c) (results-from-quote (nasdaq-quote code))
	      (format nil "NASDAQ:~A ~A (~A)" code cur c))))
      "Usage: !nasdaq <code>"))

(defcommand !intc (source args)
  (declare (ignorable source args))
  (let ((code "INTC"))
    (multiple-value-bind (cur c) (results-from-quote (nasdaq-quote code))
      (format nil "NASDAQ:~A ~A (~A)" code cur c))))
