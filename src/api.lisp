;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)

;;;; --- Response Parsing (Pure Functions) ---

(defun parse-geocoding-response (data)
  "Parse geocoding response (list of plists) into first result.
Returns a plist (:name :lat :lon) or NIL if no results."
  (when (and data (listp data) (first data))
    (let ((entry (first data)))
      (list :name (getf entry :|name|)
            :lat (getf entry :|lat|)
            :lon (getf entry :|lon|)))))

(defun unix-to-hour (unix-timestamp timezone-offset)
  "Extract hour (0-23) from a UNIX timestamp with timezone offset."
  (let ((local-time (+ unix-timestamp timezone-offset)))
    (mod (floor local-time 3600) 24)))

(defun parse-hourly-entry (entry timezone-offset)
  "Parse a single hourly forecast entry plist into an hourly-entry struct."
  (let ((weather-list (getf entry :|weather|)))
    (make-hourly-entry
     :hour (unix-to-hour (getf entry :|dt|) timezone-offset)
     :temp (float (getf entry :|temp|) 0.0)
     :condition-id (if weather-list
                       (getf (first weather-list) :|id|)
                       0)
     :pop (float (or (getf entry :|pop|) 0.0) 0.0))))

(defun parse-onecall-response (data location-name)
  "Parse onecall API response plist into a weather-card struct."
  (let* ((current (getf data :|current|))
         (weather-list (getf current :|weather|))
         (first-weather (when weather-list (first weather-list)))
         (timezone-offset (or (getf data :|timezone_offset|) 0))
         (hourly-data (getf data :|hourly|)))
    (make-weather-card
     :location-name location-name
     :latitude (float (getf data :|lat|) 0.0)
     :longitude (float (getf data :|lon|) 0.0)
     :current-temp (float (getf current :|temp|) 0.0)
     :feels-like (float (getf current :|feels_like|) 0.0)
     :humidity (getf current :|humidity|)
     :wind-speed (float (getf current :|wind_speed|) 0.0)
     :wind-direction (or (getf current :|wind_deg|) 0)
     :condition-id (if first-weather (getf first-weather :|id|) 0)
     :condition-text (if first-weather
                         (getf first-weather :|description|)
                         "unknown")
     :hourly-forecast (mapcar (lambda (e)
                                (parse-hourly-entry e timezone-offset))
                              (subseq hourly-data 0
                                      (min 12 (length hourly-data)))))))

;;;; --- API Calls (Imperative Shell) ---

(defun geocode-location (name)
  "Geocode a location name. Returns plist (:name :lat :lon) or NIL."
  (handler-case
      (let ((response (openweathermap:fetch-geocoding name :limit 1)))
        (parse-geocoding-response response))
    (error () nil)))

(defun fetch-weather-for-location (name)
  "Fetch complete weather data for a location name.
Returns a weather-card struct, possibly with error-message set."
  (handler-case
      (let ((geo (geocode-location name)))
        (unless geo
          (return-from fetch-weather-for-location
            (otenki.model:make-weather-card
             :location-name name
             :error-message (format nil "Location '~A' not found" name))))
        (let ((data (openweathermap:fetch-onecall
                     (getf geo :lat) (getf geo :lon))))
          (parse-onecall-response data (getf geo :name))))
    (error (e)
      (otenki.model:make-weather-card
       :location-name name
       :error-message (format nil "API error: ~A" e)))))
