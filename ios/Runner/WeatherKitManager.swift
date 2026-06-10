import WeatherKit
import CoreLocation
import Flutter

@available(iOS 16.0, *)
@objc public class WeatherKitManager: NSObject {
    @objc public static let shared = WeatherKitManager()
    
    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()
    
    private var weatherUpdateTimer: Timer?
    private var channel: FlutterMethodChannel?
    
    // Cache for last fetched weather
    private var lastWeatherData: [String: Any]?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func setupChannel(with controller: FlutterViewController) {
        channel = FlutterMethodChannel(name: "dev.maartje.fahrplan/weather",
                                       binaryMessenger: controller.binaryMessenger)
        channel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startWeatherUpdates":
                self?.startWeatherUpdates(result: result)
            case "stopWeatherUpdates":
                self?.stopWeatherUpdates(result: result)
            case "getCurrentWeather":
                self?.getCurrentWeather(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    func startWeatherUpdates(result: @escaping FlutterResult) {
        // Request location authorization
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            fetchWeather()
            // Set up periodic updates every 15 minutes
            weatherUpdateTimer?.invalidate()
            weatherUpdateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
                self?.fetchWeather()
            }
            result("Weather updates started")
        } else {
            result(FlutterError(code: "LocationDenied", message: "Location permission denied", details: nil))
        }
    }
    
    func stopWeatherUpdates(result: @escaping FlutterResult) {
        weatherUpdateTimer?.invalidate()
        weatherUpdateTimer = nil
        result("Weather updates stopped")
    }
    
    func getCurrentWeather(result: @escaping FlutterResult) {
        if let cached = lastWeatherData {
            result(cached)
        } else {
            fetchWeather { weatherData, error in
                if let error = error {
                    result(FlutterError(code: "WeatherError", message: error.localizedDescription, details: nil))
                } else if let weatherData = weatherData {
                    result(weatherData)
                } else {
                    result(FlutterError(code: "NoData", message: "No weather data available", details: nil))
                }
            }
        }
    }
    
    private func fetchWeather(completion: (([String: Any]?, Error?) -> Void)? = nil) {
        guard let location = locationManager.location else {
            // Try to get location first
            locationManager.requestLocation()
            completion?(nil, NSError(domain: "WeatherKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location not available"]))
            return
        }
        
        Task {
            do {
                let weather = try await weatherService.weather(for: location)
                let attribution = try await weatherService.attribution
                
                let currentWeather = weather.currentWeather
                let dailyForecast = weather.dailyForecast.first
                
                // Convert condition to OpenWeatherMap-like code
                let conditionCode = mapWeatherCondition(currentWeather.condition)
                
                // Build weather data dictionary matching Gadgetbridge format
                let currentTempKelvin = Int(currentWeather.temperature.converted(to: .kelvin).value)
                let currentTempKelvinForFallback = currentTempKelvin
                
                let todayMaxTemp: Int
                if let maxTemp = dailyForecast?.highTemperature.converted(to: .kelvin) {
                    todayMaxTemp = Int(maxTemp.value)
                } else {
                    todayMaxTemp = currentTempKelvinForFallback
                }
                
                let todayMinTemp: Int
                if let minTemp = dailyForecast?.lowTemperature.converted(to: .kelvin) {
                    todayMinTemp = Int(minTemp.value)
                } else {
                    todayMinTemp = currentTempKelvinForFallback
                }
                
                let windSpeed = Int(currentWeather.wind.speed.converted(to: .kilometersPerHour).value)
                let windDirection = Int(currentWeather.wind.direction.value)
                let precipProbability = currentWeather.precipitationIntensity.value > 0 ? 100 : 0
                let pressure = Int(currentWeather.pressure.converted(to: .millibars).value)
                let cloudCover = Int(currentWeather.cloudCover * 100)
                let feelsLikeTemp = Int(currentWeather.apparentTemperature.converted(to: .kelvin).value)
                let humidity = Int(currentWeather.humidity * 100)
                let uvIndexValue = currentWeather.uvIndex.value
                let timestamp = Int(Date().timeIntervalSince1970)
                
                // Build dictionary in parts to help type checker
                var weatherData: [String: Any] = [:]
                weatherData["timestamp"] = timestamp
                weatherData["location"] = "Current Location"
                weatherData["currentTemp"] = currentTempKelvin
                weatherData["currentConditionCode"] = conditionCode
                weatherData["currentCondition"] = currentWeather.condition.description
                weatherData["currentHumidity"] = humidity
                weatherData["todayMaxTemp"] = todayMaxTemp
                weatherData["todayMinTemp"] = todayMinTemp
                weatherData["windSpeed"] = windSpeed
                weatherData["windDirection"] = windDirection
                weatherData["uvIndex"] = uvIndexValue
                weatherData["precipProbability"] = precipProbability
                weatherData["pressure"] = pressure
                weatherData["cloudCover"] = cloudCover
                weatherData["feelsLikeTemp"] = feelsLikeTemp
                weatherData["isCurrentLocation"] = 1
                weatherData["latitude"] = location.coordinate.latitude
                weatherData["longitude"] = location.coordinate.longitude
                
                // Add hourly forecast if available
                if weather.hourlyForecast.count > 0 {
                    let hourlyData = weather.hourlyForecast.prefix(24).map { hour -> [String: Any] in
                        var hourData: [String: Any] = [:]
                        hourData["timestamp"] = Int(hour.date.timeIntervalSince1970)
                        hourData["temp"] = Int(hour.temperature.converted(to: .kelvin).value)
                        hourData["conditionCode"] = mapWeatherCondition(hour.condition)
                        hourData["humidity"] = Int(hour.humidity * 100)
                        hourData["windSpeed"] = Int(hour.wind.speed.converted(to: .kilometersPerHour).value)
                        hourData["windDirection"] = Int(hour.wind.direction.value)
                        hourData["uvIndex"] = hour.uvIndex.value
                        hourData["precipProbability"] = Int((hour.precipitationChance ?? 0) * 100)
                        return hourData
                    }
                    weatherData["hourly"] = hourlyData
                }
                
                // Add daily forecast if available
                if weather.dailyForecast.count > 0 {
                    let dailyData = weather.dailyForecast.prefix(7).map { day -> [String: Any] in
                        var dayData: [String: Any] = [:]
                        dayData["timestamp"] = Int(day.date.timeIntervalSince1970)
                        dayData["minTemp"] = Int(day.lowTemperature.converted(to: .kelvin).value)
                        dayData["maxTemp"] = Int(day.highTemperature.converted(to: .kelvin).value)
                        dayData["conditionCode"] = mapWeatherCondition(day.condition)
                        dayData["windSpeed"] = Int(day.wind.speed.converted(to: .kilometersPerHour).value)
                        dayData["windDirection"] = Int(day.wind.direction.value)
                        dayData["uvIndex"] = day.uvIndex.value
                        dayData["precipProbability"] = Int((day.precipitationChance ?? 0) * 100)
                        if let sunrise = day.sun.sunrise {
                            dayData["sunRise"] = Int(sunrise.timeIntervalSince1970)
                        }
                        if let sunset = day.sun.sunset {
                            dayData["sunSet"] = Int(sunset.timeIntervalSince1970)
                        }
                        return dayData
                    }
                    weatherData["forecasts"] = dailyData
                }
                
                self.lastWeatherData = weatherData
                
                // Send to Flutter via method channel
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onWeatherUpdate", arguments: weatherData)
                }
                
                completion?(weatherData, nil)
                
            } catch {
                print("Error fetching weather: \(error)")
                completion?(nil, error)
            }
        }
    }
    
    // Map WeatherKit conditions to OpenWeatherMap-like condition codes
    // https://openweathermap.org/weather-conditions
    private func mapWeatherCondition(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear, .mostlyClear:
            return 800 // Clear sky
        case .cloudy, .partlyCloudy, .mostlyCloudy:
            return 801 // Few clouds
        case .foggy:
            return 741 // Fog
        case .haze:
            return 721 // Haze
        case .smoky:
            return 711 // Smoke
        case .breezy, .windy:
            return 771 // Squalls
        case .drizzle:
            return 300 // Drizzle
        case .rain, .heavyRain:
            return 500 // Rain
        case .thunderstorms:
            return 200 // Thunderstorm
        case .snow, .heavySnow:
            return 600 // Snow
        case .sleet:
            return 611 // Sleet
        case .flurries:
            return 600 // Snow
        case .hail:
            return 906 // Hail
        case .blizzard:
            return 622 // Heavy snow
        case .blowingDust:
            return 731 // Dust
        case .blowingSnow:
            return 622 // Heavy snow
        case .freezingDrizzle:
            return 311 // Freezing drizzle
        case .freezingRain:
            return 511 // Freezing rain
        case .frigid:
            return 903 // Extreme cold
        case .hot:
            return 904 // Extreme heat
        case .hurricane:
            return 902 // Hurricane
        case .tropicalStorm:
            return 901 // Tropical storm
        case .sunFlurries, .sunShowers:
            return 500 // Rain
        case .strongStorms:
            return 212 // Heavy thunderstorm
        case .wintryMix:
            return 611 // Sleet
        case .scatteredThunderstorms, .isolatedThunderstorms:
            return 210 // Light thunderstorm
        @unknown default:
            return 800 // Clear
        }
    }
}

// MARK: - CLLocationManagerDelegate
@available(iOS 16.0, *)
extension WeatherKitManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updated, fetch weather
        fetchWeather()
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            fetchWeather()
        }
    }
}
