;;;; json.lisp — JSON serialization for --json mode
(in-package #:otenki.json)

(defun hourly-entry-to-plist (entry)
  "Convert an hourly-entry struct to a JSON-friendly plist."
  (list :|hour| (hourly-entry-hour entry)
        :|temp_kelvin| (hourly-entry-temp entry)
        :|condition_id| (hourly-entry-condition-id entry)
        :|precipitation_probability| (hourly-entry-pop entry)))

(defun weather-card-to-plist (card)
  "Convert a weather-card struct to a JSON-friendly plist."
  (list :|location| (weather-card-location-name card)
        :|latitude| (weather-card-latitude card)
        :|longitude| (weather-card-longitude card)
        :|temp_kelvin| (weather-card-current-temp card)
        :|feels_like_kelvin| (weather-card-feels-like card)
        :|humidity| (weather-card-humidity card)
        :|wind_speed_ms| (weather-card-wind-speed card)
        :|wind_direction_deg| (weather-card-wind-direction card)
        :|condition_id| (weather-card-condition-id card)
        :|condition_text| (weather-card-condition-text card)
        :|hourly_forecast| (mapcar #'hourly-entry-to-plist
                                   (weather-card-hourly-forecast card))))

(defun cards-to-json (cards)
  "Serialize a list of weather-card structs to a JSON string."
  (com.inuoe.jzon:stringify (mapcar #'weather-card-to-plist cards)))
