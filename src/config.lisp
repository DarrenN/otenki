;;;; config.lisp — configuration loading and CLI arg parsing
(in-package #:otenki.config)

;;;; --- Data Structures ---

(defvar *default-config-path*
  (merge-pathnames ".config/otenki/config.lisp"
                   (user-homedir-pathname))
  "Default path to the otenki config file.")

(defstruct app-config
  "Application configuration."
  (units :metric :type keyword)
  (refresh-interval 600 :type integer)
  (locations nil :type list)
  (json-mode-p nil :type boolean))

;;;; --- Config File Parsing ---

(defun parse-config-plist (plist)
  "Parse a config plist into an app-config struct."
  (make-app-config
   :units (or (getf plist :units) :metric)
   :refresh-interval (or (getf plist :refresh-interval) 600)
   :locations (getf plist :locations)))

(defun load-config-file (&optional (path *default-config-path*))
  "Load config from file at PATH. Returns default config if file missing or unreadable."
  (if (uiop:file-exists-p path)
      (handler-case
          (let ((plist (with-open-file (s path :direction :input)
                         (read s))))
            (parse-config-plist plist))
        (error (c)
          (warn "Could not read config file ~A: ~A~%Using defaults." path c)
          (make-app-config)))
      (make-app-config)))

;;;; --- CLI Argument Parsing ---

(defun parse-cli-args (args)
  "Parse command-line arguments into an app-config struct.
Returns (values app-config explicit-fields-list) where explicit-fields-list
names only those fields the user actually supplied on the command line."
  (let ((units nil)
        (json-mode nil)
        (locations nil)
        (explicit-fields nil))
    (loop with i = 0
          while (< i (length args))
          for arg = (nth i args)
          do (cond
               ((string= arg "--json")
                (setf json-mode t)
                (push :json-mode-p explicit-fields)
                (incf i))
               ((string= arg "--units")
                (incf i)
                (unless (< i (length args))
                  (error "Option --units requires an argument."))
                (let ((val (intern (string-upcase (nth i args)) :keyword)))
                  (unless (member val '(:metric :imperial))
                    (error "Unknown units ~S; expected metric or imperial." (nth i args)))
                  (setf units val)
                  (push :units explicit-fields)
                  (incf i)))
               (t
                (push arg locations)
                (push :locations explicit-fields)
                (incf i))))
    (values
     (make-app-config
      :units (or units :metric)
      :refresh-interval 600
      :locations (nreverse locations)
      :json-mode-p json-mode)
     (remove-duplicates explicit-fields))))

;;;; --- Config Resolution ---

(defun merge-configs (file-cfg cli-cfg &optional explicit-fields)
  "Merge file config with CLI config.
CLI values override file values only for fields named in EXPLICIT-FIELDS.
:json-mode-p is always OR'd (either source can enable it)."
  (make-app-config
   :units (if (member :units explicit-fields)
              (app-config-units cli-cfg)
              (app-config-units file-cfg))
   :refresh-interval (if (member :refresh-interval explicit-fields)
                         (app-config-refresh-interval cli-cfg)
                         (app-config-refresh-interval file-cfg))
   :locations (if (member :locations explicit-fields)
                  (app-config-locations cli-cfg)
                  (app-config-locations file-cfg))
   :json-mode-p (or (app-config-json-mode-p cli-cfg)
                    (app-config-json-mode-p file-cfg))))

(defun resolve-config (cli-args)
  "Build final config by merging file config with CLI args."
  (let ((file-cfg (load-config-file)))
    (multiple-value-bind (cli-cfg explicit-fields) (parse-cli-args cli-args)
      (merge-configs file-cfg cli-cfg explicit-fields))))

(defun ensure-api-key ()
  "Ensure the OpenWeatherMap API key is available.
Reads from OPENWEATHER_API_KEY env var and configures the client.
Signals an error if not set."
  (let ((key (uiop:getenv "OPENWEATHER_API_KEY")))
    (unless key
      (error "Missing OPENWEATHER_API_KEY environment variable.~%~
              Get your API key at https://openweathermap.org/api"))
    (openweathermap:configure-api-key key)
    key))
