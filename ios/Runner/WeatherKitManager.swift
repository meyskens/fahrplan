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
                let currentTempMeasurement = currentWeather.temperature.converted(to: .kelvin)
                let currentTempKelvin = Int(currentTempMeasurement.value)
                let currentTempKelvinForFallback = currentTempKelvin
                
                let maxTempMeasurement = dailyForecast?.highTemperature.converted(to: .kelvin)
                let maxTempValue = maxTempMeasurement?.value ?? Double(currentTempKelvinForFallback)
                let todayMaxTemp = Int(maxTempValue)
                
                let minTempMeasurement = dailyForecast?.lowTemperature.converted(to: .kelvin)
                let minTempValue = minTempMeasurement?.value ?? Double(currentTempKelvinForFallback)
                let todayMinTemp = Int(minTempValue)
                
                let windSpeedMeasurement = currentWeather.wind.speed.converted(to: .kilometersPerHour)
                let windSpeed = Int(windSpeedMeasurement.value)
                
                let windDirectionMeasurement = currentWeather.wind.direction
                let windDirection = Int(windDirectionMeasurement.value)
                
                let hasPrecipitation = currentWeather.precipitationIntensity.value > 0
                let precipProbability = hasPrecipitation ? 100 : 0
                
                let pressureMeasurement = currentWeather.pressure.converted(to: .millibars)
                let pressure = Int(pressureMeasurement.value)
                
                let cloudCoverValue = currentWeather.cloudCover * 100
                let cloudCover = Int(cloudCoverValue)
                
                let feelsLikeMeasurement = currentWeather.apparentTemperature.converted(to: .kelvin)
                let feelsLikeTemp = Int(feelsLikeMeasurement.value)
                
                let humidityValue = currentWeather.humidity * 100
                let humidity = Int(humidityValue)
                
                let uvIndexValue = currentWeather.uvIndex.value
                
                let timestampValue = Date().timeIntervalSince1970
                let timestamp = Int(timestampValue)
                
                var weatherData: [String: Any] = [
                    "timestamp": timestamp,
                    "location": "Current Location",
                    "currentTemp": currentTempKelvin,
                    "currentConditionCode": conditionCode,
                    "currentCondition": currentWeather.condition.description,
                    "currentHumidity": humidity,
                    "todayMaxTemp": todayMaxTemp,
                    "todayMinTemp": todayMinTemp,
                    "windSpeed": windSpeed,
                    "windDirection": windDirection,
                    "uvIndex": uvIndexValue,
                    "precipProbability": precipProbability,
                    "pressure": pressure,
                    "cloudCover": cloudCover,
                    "feelsLikeTemp": feelsLikeTemp,
                    "isCurrentLocation": 1,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude
                ]
                
                // Add hourly forecast if available
                if weather.hourlyForecast.count > 0 {
                    let hourlyData = weather.hourlyForecast.prefix(24).map { hour -> [String: Any] in
                        return [
                            "timestamp": Int(hour.date.timeIntervalSince1970),
                            "temp": Int(hour.temperature.converted(to: .kelvin).value),
                            "conditionCode": mapWeatherCondition(hour.condition),
                            "humidity": Int(hour.humidity * 100),
                            "windSpeed": Int(hour.wind.speed.converted(to: .kilometersPerHour).value),
                            "windDirection": Int(hour.wind.direction.value),
                            "uvIndex": hour.uvIndex.value,
                            "precipProbability": Int((hour.precipitationChance ?? 0) * 100)
                        ]
                    }
                    weatherData["hourly"] = hourlyData
                }
                
                // Add daily forecast if available
                if weather.dailyForecast.count > 0 {
                    let dailyData = weather.dailyForecast.prefix(7).map { day -> [String: Any] in
                        return [
                            "timestamp": Int(day.date.timeIntervalSince1970),
                            "minTemp": Int(day.lowTemperature.converted(to: .kelvin).value),
                            "maxTemp": Int(day.highTemperature.converted(to: .kelvin).value),
                            "conditionCode": mapWeatherCondition(day.condition),
                            "humidity": Int(day.humidity * 100),
                            "windSpeed": Int(day.wind.speed.converted(to: .kilometersPerHour).value),
                            "windDirection": Int(day.wind.direction.value),
                            "uvIndex": day.uvIndex.value,
                            "precipProbability": Int((day.precipitationChance ?? 0) * 100),
                            "sunRise": day.sun.sunrise != nil ? Int(day.sun.sunrise!.timeIntervalSince1970) : nil,
                            "sunSet": day.sun.sunset != nil ? Int(day.sun.sunset!.timeIntervalSince1970) : nil
                        ].compactMapValues { $0 }
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
