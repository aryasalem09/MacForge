import Foundation

/// Current conditions shown as a glance chip in the expanded island header.
struct WeatherGlance: Equatable {
    var temperatureText: String
    var symbolName: String
    var conditionDescription: String
    var locationName: String
    var fetchedAt: Date
}

/// A geocoding search hit the user can pick as their weather location.
struct WeatherLocationResult: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var latitude: Double
    var longitude: Double
    var admin1: String?
    var country: String?

    var displayName: String {
        [name, admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// Fetches current conditions from Open-Meteo (free, no API key, no account)
/// for a user-chosen location. No CoreLocation and no location permission —
/// the user types a city once in Settings; that's the only data ever sent.
@MainActor
final class WeatherGlanceCenter: ObservableObject {
    @Published private(set) var current: WeatherGlance?
    @Published private(set) var lastError: String?

    private var refreshTimer: Timer?
    private var latitude: Double?
    private var longitude: Double?
    private var locationName = ""
    private let session: URLSession
    private var usesFahrenheit: Bool

    init(session: URLSession = .shared, locale: Locale = .current) {
        self.session = session
        usesFahrenheit = Self.localePrefersFahrenheit(locale)
    }

    static func localePrefersFahrenheit(_ locale: Locale) -> Bool {
        locale.measurementSystem == .us
    }

    func configure(latitude: Double?, longitude: Double?, locationName: String?, enabled: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName ?? ""

        refreshTimer?.invalidate()
        refreshTimer = nil

        guard enabled, latitude != nil, longitude != nil else {
            current = nil
            return
        }

        let timer = Timer(timeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        Task { await refresh() }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        current = nil
    }

    func refresh() async {
        guard let latitude, let longitude else { return }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: usesFahrenheit ? "fahrenheit" : "celsius"),
        ]
        guard let url = components.url else { return }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                lastError = "Weather service returned HTTP \(http.statusCode)."
                return
            }
            if apply(responseData: data) {
                lastError = nil
            } else {
                lastError = "Unexpected weather response."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Decodes an Open-Meteo current-conditions payload. Split out (and
    /// internal) so tests can feed fixtures without a network. Returns false
    /// when the payload doesn't parse, so callers can surface the failure
    /// instead of silently keeping stale conditions.
    @discardableResult
    func apply(responseData: Data, now: Date = Date()) -> Bool {
        struct Response: Decodable {
            struct Current: Decodable {
                var temperature_2m: Double
                var weather_code: Int
                var is_day: Int?
            }
            var current: Current
        }
        guard let response = try? JSONDecoder().decode(Response.self, from: responseData) else { return false }
        let condition = Self.condition(forWMOCode: response.current.weather_code, isDay: (response.current.is_day ?? 1) == 1)
        current = WeatherGlance(
            temperatureText: "\(Int(response.current.temperature_2m.rounded()))°",
            symbolName: condition.symbolName,
            conditionDescription: condition.description,
            locationName: locationName,
            fetchedAt: now
        )
        return true
    }

    /// WMO weather interpretation codes → SF Symbol + description.
    static func condition(forWMOCode code: Int, isDay: Bool) -> (symbolName: String, description: String) {
        switch code {
        case 0:
            return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
        case 1, 2:
            return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Partly cloudy")
        case 3:
            return ("cloud.fill", "Overcast")
        case 45, 48:
            return ("cloud.fog.fill", "Fog")
        case 51, 53, 55, 56, 57:
            return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65, 66, 67:
            return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77, 85, 86:
            return ("cloud.snow.fill", "Snow")
        case 80, 81, 82:
            return ("cloud.heavyrain.fill", "Showers")
        case 95, 96, 99:
            return ("cloud.bolt.rain.fill", "Thunderstorm")
        default:
            return ("cloud.fill", "Cloudy")
        }
    }

    /// City search via Open-Meteo's geocoding API.
    static func searchLocations(matching query: String, session: URLSession = .shared) async -> [WeatherLocationResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "5"),
        ]
        guard let url = components.url else { return [] }
        struct Response: Decodable {
            var results: [WeatherLocationResult]?
        }
        guard let (data, _) = try? await session.data(from: url),
              let response = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }
        return response.results ?? []
    }
}
