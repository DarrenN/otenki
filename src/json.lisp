;;;; json.lisp — JSON serialization for --json mode
(in-package #:otenki.json)

;;; Internal helpers

(defun ht (&rest pairs)
  "Create a string-keyed hash table from alternating key/value pairs."
  (let ((table (make-hash-table :test 'equal)))
    (loop for (k v) on pairs by #'cddr
          do (setf (gethash k table) v))
    table))

(defun round1 (x)
  "Round X to one decimal place, returning a float."
  (/ (round (* x 10.0)) 10.0))

;;; Serialization

(defun hourly-entry-to-ht (entry)
  "Convert an hourly-entry struct to a string-keyed hash table."
  (ht "hour"         (hourly-entry-hour entry)
      "temp_c"       (round1 (kelvin-to-celsius (hourly-entry-temp entry)))
      "condition_id" (hourly-entry-condition-id entry)
      "pop"          (hourly-entry-pop entry)))

(defun daily-entry-to-ht (entry)
  "Convert a daily-entry struct to a string-keyed hash table."
  (ht "day"          (daily-entry-day-name entry)
      "temp_min_c"   (round1 (kelvin-to-celsius (daily-entry-temp-min entry)))
      "temp_max_c"   (round1 (kelvin-to-celsius (daily-entry-temp-max entry)))
      "condition_id" (daily-entry-condition-id entry)))

(defun weather-card-to-ht (card)
  "Convert a weather-card struct to a string-keyed hash table.
Temperature values are converted from Kelvin to Celsius (1 decimal place).
The returned hash table is suitable for direct JSON serialization."
  (ht "location"      (weather-card-location-name card)
      "lat"           (weather-card-latitude card)
      "lon"           (weather-card-longitude card)
      "temp_c"        (round1 (kelvin-to-celsius (weather-card-current-temp card)))
      "feels_like_c"  (round1 (kelvin-to-celsius (weather-card-feels-like card)))
      "humidity"      (weather-card-humidity card)
      "wind_speed_ms" (weather-card-wind-speed card)
      "wind_dir"      (weather-card-wind-direction card)
      "condition_id"  (weather-card-condition-id card)
      "condition"     (weather-card-condition-text card)
      "hourly"        (mapcar #'hourly-entry-to-ht
                              (weather-card-hourly-forecast card))
      "daily"         (mapcar #'daily-entry-to-ht
                              (weather-card-daily-forecast card))))

(defun cards-to-json (cards)
  "Serialize a list of weather-card structs to a JSON array string."
  (com.inuoe.jzon:stringify (map 'vector #'weather-card-to-ht cards)))
