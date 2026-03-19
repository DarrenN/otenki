;;;; model.lisp — pure data structures and transformations
(in-package #:otenki.model)

;;;; --- Data Structures ---

(defstruct weather-card
  "A single location's weather snapshot."
  (location-name "" :type string)
  (latitude 0.0 :type float)
  (longitude 0.0 :type float)
  (current-temp 0.0 :type float)       ; Kelvin
  (feels-like 0.0 :type float)         ; Kelvin
  (humidity 0 :type integer)           ; percentage
  (wind-speed 0.0 :type float)         ; m/s
  (wind-direction 0 :type integer)     ; degrees
  (condition-id 0 :type integer)       ; OWM condition code
  (condition-text "" :type string)
  (hourly-forecast nil :type list)     ; list of hourly-entry
  (daily-forecast nil :type list)     ; list of daily-entry
  (error-message nil :type (or null string)))

(defstruct hourly-entry
  "One hour of forecast data."
  (hour 0 :type integer)               ; 0-23
  (temp 0.0 :type float)              ; Kelvin
  (condition-id 0 :type integer)
  (pop 0.0 :type float))              ; probability of precipitation

(defstruct daily-entry
  "One day of forecast data."
  (day-name "" :type string)          ; "Mon", "Tue", etc.
  (temp-min 0.0 :type float)         ; Kelvin
  (temp-max 0.0 :type float)         ; Kelvin
  (condition-id 0 :type integer))    ; OWM condition code

;;;; --- Unit Conversion (Pure Functions) ---

(defun kelvin-to-celsius (k)
  "Convert Kelvin to Celsius."
  (- k 273.15))

(defun kelvin-to-fahrenheit (k)
  "Convert Kelvin to Fahrenheit."
  (+ (* (kelvin-to-celsius k) 9/5) 32.0))

(defun format-temp (kelvin units)
  "Format a Kelvin temperature for display in UNITS (:metric or :imperial)."
  (ecase units
    (:metric (format nil "~D°C" (round (kelvin-to-celsius kelvin))))
    (:imperial (format nil "~D°F" (round (kelvin-to-fahrenheit kelvin))))))

(defun ms-to-mph (ms)
  "Convert meters/second to miles/hour."
  (* ms 2.237))

(defun format-wind-speed (speed units)
  "Format wind speed for display in UNITS (:metric or :imperial)."
  (ecase units
    (:metric (format nil "~,1F m/s" speed))
    (:imperial (format nil "~,1F mph" (ms-to-mph speed)))))
