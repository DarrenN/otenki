;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)

;;;; --- Response Parsing (Pure Functions) ---
;;;;
;;;; The openweathermap v0.2.0 client returns string-keyed hash tables
;;;; (via com.inuoe.jzon).  JSON arrays are vectors.  We use the library's
;;;; ht-get helper for nested access.

(defun parse-geocoding-response (data)
  "Parse geocoding response (vector of hash-tables) into first result.
Returns a plist (:name :lat :lon) or NIL if no results."
  (when (and data
             (vectorp data)
             (plusp (length data)))
    (let ((entry (aref data 0)))
      (list :name (openweathermap:ht-get entry "name")
            :lat (float (openweathermap:ht-get entry "lat") 0.0)
            :lon (float (openweathermap:ht-get entry "lon") 0.0)))))

(defun unix-to-hour (unix-timestamp timezone-offset)
  "Extract hour (0-23) from a UNIX timestamp with timezone offset."
  (let ((local-time (+ unix-timestamp timezone-offset)))
    (mod (floor local-time 3600) 24)))

(defun parse-hourly-entry (entry timezone-offset)
  "Parse a single hourly forecast hash-table into an hourly-entry struct."
  (let ((weather-vec (openweathermap:ht-get entry "weather")))
    (make-hourly-entry
     :hour (unix-to-hour (openweathermap:ht-get entry "dt") timezone-offset)
     :temp (float (openweathermap:ht-get entry "temp") 0.0)
     :condition-id (if (and weather-vec (plusp (length weather-vec)))
                       (openweathermap:ht-get (aref weather-vec 0) "id")
                       0)
     :pop (float (or (openweathermap:ht-get entry "pop") 0.0) 0.0))))

(defun parse-onecall-response (data location-name)
  "Parse onecall API response hash-table into a weather-card struct."
  (let* ((current (openweathermap:ht-get data "current"))
         (weather-vec (openweathermap:ht-get current "weather"))
         (first-weather (when (and weather-vec (plusp (length weather-vec)))
                          (aref weather-vec 0)))
         (timezone-offset (or (openweathermap:ht-get data "timezone_offset") 0))
         (hourly-data (openweathermap:ht-get data "hourly")))
    (make-weather-card
     :location-name location-name
     :latitude (float (openweathermap:ht-get data "lat") 0.0)
     :longitude (float (openweathermap:ht-get data "lon") 0.0)
     :current-temp (float (openweathermap:ht-get current "temp") 0.0)
     :feels-like (float (openweathermap:ht-get current "feels_like") 0.0)
     :humidity (openweathermap:ht-get current "humidity")
     :wind-speed (float (openweathermap:ht-get current "wind_speed") 0.0)
     :wind-direction (or (openweathermap:ht-get current "wind_deg") 0)
     :condition-id (if first-weather
                       (openweathermap:ht-get first-weather "id")
                       0)
     :condition-text (if first-weather
                         (openweathermap:ht-get first-weather "description")
                         "unknown")
     :hourly-forecast (map 'list
                           (lambda (e)
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
