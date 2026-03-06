;;;; view.lisp — pure rendering functions
;;;;
;;;; This module contains all UI rendering logic. Functions here are pure:
;;;; they take weather-card data and return formatted strings. No I/O occurs.
;;;; The tuition (tui) library is used for borders, layout, and styling.

(in-package #:otenki.view)

;;;; --- Condition Icons ---

(defun condition-icon (condition-id)
  "Map an OWM condition ID to a colored Unicode weather icon.
Returns a pre-colored string via tui:colored. Single-width characters only.
Condition ranges follow OWM documentation:
  2xx — Thunderstorm, 3xx — Drizzle, 5xx — Rain,
  6xx — Snow, 7xx — Atmosphere (fog/mist), 800 — Clear, 8xx — Clouds."
  (cond
    ((< condition-id 300) (tui:colored "⚡" :fg tui:*fg-magenta*))
    ((< condition-id 400) (tui:colored "☂" :fg tui:*fg-cyan*))
    ((< condition-id 600) (tui:colored "☂" :fg tui:*fg-blue*))
    ((< condition-id 700) (tui:colored "❄" :fg tui:*fg-bright-white*))
    ((< condition-id 800) (tui:colored "≋" :fg tui:*fg-bright-black*))
    ((= condition-id 800) (tui:colored "☀" :fg tui:*fg-yellow*))
    (t                    (tui:colored "☁" :fg tui:*fg-bright-black*))))

;;;; --- Temperature Colors ---

(defun temp-color (kelvin)
  "Return a foreground color parameter based on temperature in Kelvin.
Converts to Celsius internally for threshold comparison.
  <=5C -> blue, 5-15C -> cyan, 15-25C -> green, 25-35C -> yellow, >35C -> red."
  (let ((celsius (kelvin-to-celsius kelvin)))
    (cond
      ((<= celsius 5.0)  tui:*fg-blue*)
      ((<= celsius 15.0) tui:*fg-cyan*)
      ((<= celsius 25.0) tui:*fg-green*)
      ((<= celsius 35.0) tui:*fg-yellow*)
      (t                  tui:*fg-red*))))

;;;; --- Hourly Forecast Row ---

(defvar +max-hourly-entries+ 8
  "Maximum number of hourly forecast entries to display per card.")

(defun render-hourly-row (entries units)
  "Render a compact hourly forecast as two rows: hours then temps.
ENTRIES is a list of hourly-entry structs. UNITS is :metric or :imperial.
Each column is padded to the wider of its hour label or temp value.
At most +MAX-HOURLY-ENTRIES+ entries are shown to prevent overflow.
Returns a newline-separated string of two rows, or NIL if entries is empty."
  (when entries
    (let* ((capped (subseq entries 0 (min (length entries) +max-hourly-entries+)))
           (hours (mapcar (lambda (e)
                            (format nil "~2,'0Dh" (hourly-entry-hour e)))
                          capped))
           (temps (mapcar (lambda (e)
                            (format-temp (hourly-entry-temp e) units))
                          capped))
           (widths (mapcar (lambda (h tmp)
                             (max (length h) (length tmp)))
                           hours temps))
           (hour-strs (mapcar (lambda (h w)
                                (format nil "~VA" (1+ w) h))
                              hours widths))
           (temp-strs (mapcar (lambda (tmp w)
                                (format nil "~VA" (1+ w) tmp))
                              temps widths)))
      (format nil "~{~A~}~%~{~A~}" hour-strs temp-strs))))

;;;; --- Single Card Rendering ---

(defun render-weather-card (card units)
  "Render a single weather card as a bordered string.
CARD is a weather-card struct. UNITS is :metric or :imperial.
Returns a multi-line string suitable for terminal display.

Error cards display only the error message inside a border.
Normal cards show a hero line (icon + temp + feels-like), aligned detail
rows (humidity, wind, condition), and an hourly forecast row."
  (if (weather-card-error-message card)
      ;; Error card: show only the error message
      (tui:render-border
       (format nil "Error~%~%~A" (weather-card-error-message card))
       tui:*border-rounded*
       :title (weather-card-location-name card)
       :fg-color tui:*fg-bright-black*)
      ;; Normal card
      (let* ((icon (condition-icon (weather-card-condition-id card)))
             (temp-fg (temp-color (weather-card-current-temp card)))
             (temp-str (tui:colored (format-temp (weather-card-current-temp card) units)
                                    :fg temp-fg))
             (feels-str (tui:colored (format-temp (weather-card-feels-like card) units)
                                     :fg temp-fg))
             (hero-line (format nil "~A ~A  feels ~A"
                                icon temp-str feels-str))
             (humidity-line (format nil "~14A~D%" "Humidity" (weather-card-humidity card)))
             (wind-line (format nil "~14A~A" "Wind"
                                (format-wind-speed (weather-card-wind-speed card) units)))
             (condition-line (format nil "~14A~A" "Condition"
                                     (weather-card-condition-text card)))
             (hourly (render-hourly-row
                      (weather-card-hourly-forecast card) units))
             (body (format nil "~A~%~%~A~%~A~%~A~@[~%~%~A~]"
                           hero-line humidity-line wind-line
                           condition-line hourly)))
        (tui:render-border body tui:*border-rounded*
                           :title (tui:bold (weather-card-location-name card))
                           :fg-color tui:*fg-bright-black*))))

;;;; --- Grid Layout ---

(defun render-card-grid (cards units terminal-width)
  "Render weather cards in a responsive grid layout.
CARDS is a list of weather-card structs. UNITS is :metric or :imperial.
TERMINAL-WIDTH is the number of terminal columns available.

Cards are arranged into rows based on an estimated card width of 36 columns,
then joined horizontally per row and vertically across rows.  Cards within a
row are padded to equal height before joining to prevent border artifacts."
  (let* ((card-width 36)
         (cards-per-row (max 1 (floor terminal-width card-width)))
         (rendered (mapcar (lambda (c) (render-weather-card c units)) cards))
         (rows (loop for i from 0 below (length rendered) by cards-per-row
                     collect (subseq rendered i
                                     (min (+ i cards-per-row)
                                          (length rendered))))))
    (apply #'tui:join-vertical tui:+left+
           (mapcar (lambda (row)
                     (let ((max-h (reduce #'max row :key #'tui:height)))
                       (apply #'tui:join-horizontal tui:+top+
                              (loop for (card . rest) on row
                                    collect (tui:place-vertical max-h tui:+top+ card)
                                    when rest collect "  "))))
                   rows))))

;;;; --- Status Bar ---

(defun render-status-bar (last-updated next-refresh-time loading-p
                          location-count units)
  "Render the bottom status bar.
LAST-UPDATED is a universal-time integer or NIL.
NEXT-REFRESH-TIME is the universal-time of the next auto-refresh, or NIL.
LOADING-P is T when a background refresh is in progress.
LOCATION-COUNT is the number of configured locations.
UNITS is :metric or :imperial."
  (let* ((keys (tui:colored "[r] Refresh  [q] Quit" :fg tui:*fg-bright-black*))
         (info (format nil "~D location~:P · ~(~A~)" location-count units))
         (updated (cond
                    (loading-p "Refreshing...")
                    (last-updated
                     (multiple-value-bind (s m h)
                         (decode-universal-time last-updated)
                       (declare (ignore s))
                       (format nil "Updated ~2,'0D:~2,'0D" h m)))
                    (t "Not yet updated")))
         (countdown (when (and next-refresh-time (not loading-p))
                      (let ((remaining (- next-refresh-time (get-universal-time))))
                        (when (plusp remaining)
                          (format nil "Next in ~D:~2,'0D"
                                  (floor remaining 60)
                                  (mod remaining 60))))))
         (time-section (if countdown
                           (format nil "~A · ~A" updated countdown)
                           updated)))
    (format nil "~A  │  ~A  │  ~A" keys info time-section)))

;;;; --- Full Application Render ---

(defun render-app (cards units terminal-width last-updated
                   next-refresh-time loading-p error-message
                   location-count)
  "Render the complete application view as a single string.
CARDS is a list of weather-card structs (may be NIL).
UNITS is :metric or :imperial.
TERMINAL-WIDTH is the number of terminal columns.
LAST-UPDATED is a universal-time integer or NIL.
NEXT-REFRESH-TIME is the universal-time of the next auto-refresh, or NIL.
LOADING-P is T when a background fetch is running.
ERROR-MESSAGE, if non-NIL, is appended in red below the status bar.
LOCATION-COUNT is the number of configured locations."
  (let* ((title (tui:bold "otenki"))
         (grid (cond
                 (cards
                  (render-card-grid cards units terminal-width))
                 (loading-p
                  "Loading weather data...")
                 (t
                  "No locations configured. Add locations to ~/.config/otenki/config.lisp")))
         (status (render-status-bar last-updated next-refresh-time
                                    loading-p location-count units))
         (parts (list title "" grid "" status)))
    (when error-message
      (setf parts (append parts (list (tui:colored error-message :fg tui:*fg-red*)))))
    (apply #'tui:join-vertical tui:+left+ parts)))
