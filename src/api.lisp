;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)

;;;; --- Response Parsing (Pure Functions) ---
;;;;
;;;; The openweathermap client library normalizes JSON keys to uppercase
;;;; keywords (e.g. :TEMP, :LAT) via string-upcase + intern.  All getf
;;;; lookups below use uppercase keywords to match.

(defun parse-geocoding-response (data)
  "Parse geocoding response (list of plists) into first result.
Returns a plist (:name :lat :lon) or NIL if no results."
  (when (and data (listp data) (first data))
    (let ((entry (first data)))
      (list :name (getf entry :NAME)
            :lat (float (getf entry :LAT) 0.0)
            :lon (float (getf entry :LON) 0.0)))))

(defun unix-to-hour (unix-timestamp timezone-offset)
  "Extract hour (0-23) from a UNIX timestamp with timezone offset."
  (let ((local-time (+ unix-timestamp timezone-offset)))
    (mod (floor local-time 3600) 24)))

(defun parse-hourly-entry (entry timezone-offset)
  "Parse a single hourly forecast entry plist into an hourly-entry struct."
  (let ((weather-list (getf entry :WEATHER)))
    (make-hourly-entry
     :hour (unix-to-hour (getf entry :DT) timezone-offset)
     :temp (float (getf entry :TEMP) 0.0)
     :condition-id (if weather-list
                       (getf (first weather-list) :ID)
                       0)
     :pop (float (or (getf entry :POP) 0.0) 0.0))))

(defun parse-onecall-response (data location-name)
  "Parse onecall API response plist into a weather-card struct."
  (let* ((current (getf data :CURRENT))
         (weather-list (getf current :WEATHER))
         (first-weather (when weather-list (first weather-list)))
         (timezone-offset (or (getf data :TIMEZONE_OFFSET) 0))
         (hourly-data (getf data :HOURLY)))
    (make-weather-card
     :location-name location-name
     :latitude (float (getf data :LAT) 0.0)
     :longitude (float (getf data :LON) 0.0)
     :current-temp (float (getf current :TEMP) 0.0)
     :feels-like (float (getf current :FEELS_LIKE) 0.0)
     :humidity (getf current :HUMIDITY)
     :wind-speed (float (getf current :WIND_SPEED) 0.0)
     :wind-direction (or (getf current :WIND_DEG) 0)
     :condition-id (if first-weather (getf first-weather :ID) 0)
     :condition-text (if first-weather
                         (getf first-weather :DESCRIPTION)
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
