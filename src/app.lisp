;;;; app.lisp — TEA wiring for the TUI
;;;
;;; This is the imperative shell that connects the cl-tuition TEA loop to
;;; the pure-functional core (model, api, view).  No unit tests are written
;;; for this file; correctness is verified by running the TUI interactively.
(in-package #:otenki.app)

;;;; --- Custom Messages ---

(tui:defmessage weather-received-msg
  ((card :initarg :card :reader weather-received-msg-card))
  :documentation "Carries a successfully-fetched weather-card.")

(tui:defmessage weather-error-msg
  ((location :initarg :location :reader weather-error-msg-location)
   (message  :initarg :message  :reader weather-error-msg-message))
  :documentation "Carries a fetch error for a single location.")

(tui:defmessage refresh-msg ()
  :documentation "Triggers a full weather refresh on the auto-refresh timer.")

;;;; --- App Model ---

(defclass otenki-model ()
  ((cards
    :accessor otenki-model-cards
    :initarg  :cards
    :initform nil
    :type     list
    :documentation "List of weather-card structs, one per location.")
   (units
    :accessor otenki-model-units
    :initarg  :units
    :initform :metric
    :type     keyword
    :documentation "Display units: :metric or :imperial.")
   (locations
    :accessor otenki-model-locations
    :initarg  :locations
    :initform nil
    :type     list
    :documentation "List of location name strings to fetch.")
   (last-updated
    :accessor otenki-model-last-updated
    :initarg  :last-updated
    :initform nil
    :documentation "Universal time of last successful update, or NIL.")
   (refresh-interval
    :accessor otenki-model-refresh-interval
    :initarg  :refresh-interval
    :initform 600
    :type     integer
    :documentation "Auto-refresh interval in seconds.")
   (next-refresh-time
    :accessor otenki-model-next-refresh-time
    :initarg  :next-refresh-time
    :initform nil
    :documentation "Universal time of the next scheduled refresh, or NIL.")
   (error-message
    :accessor otenki-model-error-message
    :initarg  :error-message
    :initform nil
    :documentation "Global error string, or NIL when there is no error.")
   (loading-p
    :accessor otenki-model-loading-p
    :initarg  :loading-p
    :initform nil
    :type     boolean
    :documentation "T while at least one fetch is in progress.")
   (terminal-width
    :accessor otenki-model-terminal-width
    :initarg  :terminal-width
    :initform 80
    :type     integer
    :documentation "Current terminal width in columns."))
  (:documentation "TEA model for the otenki weather TUI."))

(defun make-otenki-model (&key locations units refresh-interval)
  "Create an initial otenki-model from a resolved app-config.
Sets loading-p to T so the view shows a loading indicator immediately."
  (make-instance 'otenki-model
                 :locations       locations
                 :units           (or units :metric)
                 :refresh-interval (or refresh-interval 600)
                 :loading-p       t))

;;;; --- Commands ---

(defun make-fetch-cmd (location)
  "Return a command (lambda) that fetches weather for a single LOCATION.
On success it produces a weather-received-msg; on error a weather-error-msg."
  (lambda ()
    (handler-case
        (let ((card (fetch-weather-for-location location)))
          (make-instance 'weather-received-msg :card card))
      (error (e)
        (make-instance 'weather-error-msg
                       :location location
                       :message  (format nil "~A" e))))))

(defun make-fetch-all-cmd (locations)
  "Return a batch command that fetches weather for every location in LOCATIONS
concurrently."
  (apply #'tui:batch (mapcar #'make-fetch-cmd locations)))

;;;; --- TEA Protocol ---

(defmethod tui:init ((model otenki-model))
  "Initialize the program: kick off fetches for all configured locations and
schedule the first auto-refresh tick."
  (setf (otenki-model-next-refresh-time model)
        (+ (get-universal-time) (otenki-model-refresh-interval model)))
  (when (otenki-model-locations model)
    (tui:batch
     (make-fetch-all-cmd (otenki-model-locations model))
     (tui:tick (otenki-model-refresh-interval model)
               (lambda () (make-instance 'refresh-msg))))))

;;; Handle a successful weather data arrival.
(defmethod tui:update-message ((model otenki-model) (msg weather-received-msg))
  "Replace or insert the arriving card in the model's card list,
then sort cards to match the configured location order."
  (let* ((card    (weather-received-msg-card msg))
         (name    (otenki.model:weather-card-location-name card))
         (updated (cons card
                        (remove-if (lambda (c)
                                     (string-equal
                                      (otenki.model:weather-card-location-name c)
                                      name))
                                   (otenki-model-cards model)))))
    (setf (otenki-model-cards       model)
          (sort updated #'<
                :key (lambda (c)
                       (or (position (otenki.model:weather-card-location-name c)
                                     (otenki-model-locations model)
                                     :test #'string-equal)
                           most-positive-fixnum)))
          (otenki-model-last-updated model) (get-universal-time)
          (otenki-model-loading-p    model) nil)
    (values model nil)))

;;; Handle a weather fetch error by inserting an error card.
(defmethod tui:update-message ((model otenki-model) (msg weather-error-msg))
  "Insert an error weather-card so the view can display the failure inline,
then sort cards to match the configured location order."
  (let* ((location   (weather-error-msg-location msg))
         (err-text   (weather-error-msg-message  msg))
         (error-card (otenki.model:make-weather-card
                      :location-name location
                      :error-message err-text))
         (updated    (cons error-card
                           (remove-if (lambda (c)
                                        (string-equal
                                         (otenki.model:weather-card-location-name c)
                                         location))
                                      (otenki-model-cards model)))))
    (setf (otenki-model-cards    model)
          (sort updated #'<
                :key (lambda (c)
                       (or (position (otenki.model:weather-card-location-name c)
                                     (otenki-model-locations model)
                                     :test #'string-equal)
                           most-positive-fixnum)))
          (otenki-model-loading-p model) nil)
    (values model nil)))

;;; Handle the auto-refresh timer.
(defmethod tui:update-message ((model otenki-model) (msg refresh-msg))
  "Trigger a full re-fetch and schedule the next timer tick."
  (setf (otenki-model-loading-p model) t
        (otenki-model-next-refresh-time model)
        (+ (get-universal-time) (otenki-model-refresh-interval model)))
  (values model
          (tui:batch
           (make-fetch-all-cmd (otenki-model-locations model))
           (tui:tick (otenki-model-refresh-interval model)
                     (lambda () (make-instance 'refresh-msg))))))

;;; Handle keyboard input.
(defmethod tui:update-message ((model otenki-model) (msg tui:key-press-msg))
  "q — quit; r — force refresh; everything else is ignored."
  (let ((key (tui:key-event-code msg)))
    (cond
      ((and (characterp key) (char= key #\q))
       (values model (tui:quit-cmd)))
      ((and (characterp key) (char= key #\r))
       (setf (otenki-model-loading-p model) t)
       (values model (make-fetch-all-cmd (otenki-model-locations model))))
      (t (values model nil)))))

;;; Handle terminal resize.
(defmethod tui:update-message ((model otenki-model) (msg tui:window-size-msg))
  "Store the new terminal width so the view can reflow its card grid."
  (setf (otenki-model-terminal-width model) (tui:window-size-msg-width msg))
  (values model nil))

;;;; --- View ---

(defmethod tui:view ((model otenki-model))
  "Delegate rendering to the pure view layer.
Returns a view-state with alt-screen enabled."
  (tui:make-view
   (render-app (otenki-model-cards            model)
               (otenki-model-units            model)
               (otenki-model-terminal-width   model)
               (otenki-model-last-updated     model)
               (otenki-model-next-refresh-time model)
               (get-universal-time)
               (otenki-model-loading-p        model)
               (otenki-model-error-message    model)
               (length (otenki-model-locations model)))
   :alt-screen t))

;;;; --- Entry Point ---

(defun run-tui (config)
  "Launch the TUI with the given APP-CONFIG.  Blocks until the user quits."
  (let* ((model   (make-otenki-model
                   :locations        (app-config-locations        config)
                   :units            (app-config-units            config)
                   :refresh-interval (app-config-refresh-interval config)))
         (program (tui:make-program model :pool-size nil)))
    (tui:run program)))
