;;;; package.lisp — package definitions for otenki

(defpackage #:otenki.model
  (:use #:cl)
  (:export #:weather-card
           #:make-weather-card
           #:weather-card-location-name
           #:weather-card-latitude
           #:weather-card-longitude
           #:weather-card-current-temp
           #:weather-card-feels-like
           #:weather-card-humidity
           #:weather-card-wind-speed
           #:weather-card-wind-direction
           #:weather-card-condition-id
           #:weather-card-condition-text
           #:weather-card-hourly-forecast
           #:weather-card-error-message
           #:hourly-entry
           #:make-hourly-entry
           #:hourly-entry-hour
           #:hourly-entry-temp
           #:hourly-entry-condition-id
           #:hourly-entry-pop
           #:kelvin-to-celsius
           #:kelvin-to-fahrenheit
           #:format-temp
           #:format-wind-speed))

(defpackage #:otenki.config
  (:use #:cl)
  (:export #:*default-config-path*
           #:app-config
           #:make-app-config
           #:app-config-units
           #:app-config-refresh-interval
           #:app-config-locations
           #:app-config-json-mode-p
           #:load-config-file
           #:parse-cli-args
           #:parse-config-plist
           #:merge-configs
           #:resolve-config
           #:ensure-api-key))

(defpackage #:otenki.api
  (:use #:cl)
  (:import-from #:otenki.model
                #:make-weather-card
                #:make-hourly-entry)
  (:export #:geocode-location
           #:fetch-weather-for-location
           #:parse-onecall-response
           #:parse-geocoding-response))

(defpackage #:otenki.view
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:weather-card-location-name
                #:weather-card-current-temp
                #:weather-card-feels-like
                #:weather-card-humidity
                #:weather-card-wind-speed
                #:weather-card-wind-direction
                #:weather-card-condition-text
                #:weather-card-hourly-forecast
                #:weather-card-error-message
                #:hourly-entry-hour
                #:hourly-entry-temp
                #:hourly-entry-pop
                #:format-temp
                #:format-wind-speed)
  (:export #:render-weather-card
           #:render-card-grid
           #:render-status-bar
           #:render-app))

(defpackage #:otenki.json
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:weather-card-location-name
                #:weather-card-latitude
                #:weather-card-longitude
                #:weather-card-current-temp
                #:weather-card-feels-like
                #:weather-card-humidity
                #:weather-card-wind-speed
                #:weather-card-wind-direction
                #:weather-card-condition-id
                #:weather-card-condition-text
                #:weather-card-hourly-forecast
                #:hourly-entry-hour
                #:hourly-entry-temp
                #:hourly-entry-condition-id
                #:hourly-entry-pop)
  (:export #:weather-card-to-plist
           #:cards-to-json))

(defpackage #:otenki.app
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:make-weather-card)
  (:import-from #:otenki.config
                #:app-config
                #:app-config-units
                #:app-config-refresh-interval
                #:app-config-locations)
  (:import-from #:otenki.api
                #:fetch-weather-for-location)
  (:import-from #:otenki.view
                #:render-app)
  (:export #:otenki-model
           #:make-otenki-model
           #:run-tui))

(defpackage #:otenki.main
  (:use #:cl)
  (:import-from #:otenki.config
                #:parse-cli-args
                #:resolve-config
                #:ensure-api-key
                #:app-config-json-mode-p
                #:app-config-locations
                #:app-config-units)
  (:import-from #:otenki.app
                #:run-tui)
  (:import-from #:otenki.api
                #:fetch-weather-for-location)
  (:import-from #:otenki.json
                #:cards-to-json)
  (:export #:main))

