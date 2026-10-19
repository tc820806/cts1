pragma Singleton
// Weather from open-meteo.com. Sent per Config.weather.mode: "off" nothing (icon hidden); "city" the city to the
// geocoding API, then its coordinates to the forecast API every 15 min; "auto" first ipinfo.io for a location from
// the IP. Every request also shows the service your IP.
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string mode: Config.ready ? Config.weather.mode : "off"
    readonly property string cityQuery: Config.weather.city.trim()
    readonly property bool celsius: Config.weather.celsius
    readonly property bool enabled: mode === "city" || mode === "auto"

    property string city: ""
    property string loc: ""             // "lat,lon"
    property var cc: null               // current conditions
    property var forecast: []           // daily
    property var hourly: []             // hourly (upcoming)
    property string error: ""
    property bool retryable: false      // the error can fix itself (network, bad reply); "not found" can't

    readonly property bool configured: mode === "auto" || (mode === "city" && cityQuery !== "")
    property int generation: 0          // bumped on every reload, so answers to an older request are dropped
    readonly property string icon: cc ? iconFor(cc.weatherCode, cc.isDay) : "cloud_alert"
    readonly property string description: cc ? conditionFor(cc.weatherCode) : (error !== "" ? error : configured ? "Loading…" : enabled ? "No city set" : "Weather is off")
    readonly property string temp: formatTemp(cc ? cc.tempC : undefined)
    readonly property string feelsLike: formatTemp(cc ? cc.feelsLikeC : undefined)
    readonly property int humidity: cc ? cc.humidity : 0
    readonly property real windSpeed: cc ? cc.windSpeed : 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), "h:mm A") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), "h:mm A") : "--:--"

    function toUnit(c) {
        return celsius ? c : c * 9 / 5 + 32;
    }
    function formatTemp(c) {
        if (c === undefined || c === null)
            return "--°";
        return Math.round(toUnit(c)) + "°" + (celsius ? "C" : "F");
    }

    function fail(msg, canRetry) {
        error = msg;
        retryable = canRetry;
    }

    function get(url, cb, gen) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE || gen !== root.generation)
                return;
            if (x.status === 200) {
                try {
                    cb(JSON.parse(x.responseText));
                } catch (e) {
                    root.fail("parse error: " + e, true);
                }
            } else {
                root.fail("HTTP " + x.status, true);
            }
        };
        x.open("GET", url);
        x.send();
    }

    function reload() {
        const gen = ++generation;
        city = "";
        loc = "";
        cc = null;
        forecast = [];
        hourly = [];
        error = "";
        retryable = false;
        if (!configured)
            return;
        if (mode === "auto") {
            get("https://ipinfo.io/json", j => {
                if (!j.loc) {
                    root.fail("Location not found", false);
                    return;
                }
                root.city = j.city || "";
                root.loc = j.loc;
                fetchForecast();
            }, gen);
            return;
        }
        get("https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" + encodeURIComponent(cityQuery), j => {
            if (!j.results || j.results.length === 0) {
                root.fail("City not found", false);
                return;
            }
            root.city = j.results[0].name;
            root.loc = j.results[0].latitude + "," + j.results[0].longitude;
            fetchForecast();
        }, gen);
    }

    function fetchForecast() {
        if (!configured || loc === "")
            return;
        error = "";
        retryable = false;
        const [lat, lon] = loc.split(",");
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&hourly=weather_code,temperature_2m,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
            + "&timezone=auto&forecast_days=7";
        get(url, j => {
            if (!j.current || !j.daily || !j.hourly) {
                root.fail("Incomplete forecast", true);
                return;
            }
            root.cc = {
                weatherCode: j.current.weather_code, tempC: j.current.temperature_2m,
                feelsLikeC: j.current.apparent_temperature, humidity: j.current.relative_humidity_2m,
                windSpeed: j.current.wind_speed_10m, isDay: j.current.is_day,
                sunrise: j.daily.sunrise[0].replace("T", " "), sunset: j.daily.sunset[0].replace("T", " ")
            };
            const d = [];
            for (let i = 0; i < j.daily.time.length; i++)
                d.push({ date: j.daily.time[i].replace(/-/g, "/"), maxTempC: j.daily.temperature_2m_max[i],
                         minTempC: j.daily.temperature_2m_min[i], weatherCode: j.daily.weather_code[i],
                         icon: iconFor(j.daily.weather_code[i], 1) });
            root.forecast = d;
            const h = [], now = new Date();
            for (let i = 0; i < j.hourly.time.length; i++) {
                const t = new Date(j.hourly.time[i].replace("T", " "));
                if (t < now)
                    continue;
                h.push({ hour: t.getHours(), tempC: Math.round(j.hourly.temperature_2m[i]),
                         precipChance: j.hourly.precipitation_probability[i],
                         weatherCode: j.hourly.weather_code[i], icon: iconFor(j.hourly.weather_code[i], 1) });
            }
            root.hourly = h;
        }, generation);
    }

    function iconFor(code, isDay) {
        if (code <= 1)
            return isDay ? "clear_day" : "clear_night";
        if (code === 2)
            return isDay ? "partly_cloudy_day" : "partly_cloudy_night";
        if (code === 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "foggy";
        if (code >= 51 && code <= 57)
            return "rainy_light";
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))
            return code === 65 || code === 67 || code === 82 ? "rainy_heavy" : "rainy";
        if (code >= 71 && code <= 77)
            return "cloudy_snowing";
        if (code === 85 || code === 86)
            return "snowing";
        if (code >= 95)
            return "thunderstorm";
        return "cloud";
    }

    function conditionFor(code) {
        const m = { 0: "Clear", 1: "Clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Fog",
                    51: "Drizzle", 53: "Drizzle", 55: "Drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
                    61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Light rain", 67: "Heavy rain",
                    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow", 80: "Light rain", 81: "Rain",
                    82: "Heavy rain", 85: "Light snow showers", 86: "Heavy snow showers", 95: "Thunderstorm",
                    96: "Thunderstorm with hail", 99: "Thunderstorm with hail" };
        return m[code] || "Unknown";
    }

    // Re-fetch when the settings change (the city is only written on Enter). Qt.callLater: once, after the other
    // bindings (`configured`) caught up.
    onModeChanged: Qt.callLater(reload)
    onCityQueryChanged: if (mode === "city") Qt.callLater(reload)

    Timer {
        interval: 900000   // 15 min: open-meteo updates "current" data every 900 s, so faster is pointless
        running: root.configured
        repeat: true
        // Same location, fresh forecast; retries the location lookup if it never worked.
        onTriggered: root.loc === "" ? root.reload() : root.fetchForecast()
    }

    // Quick retry while nothing is shown and the failure can fix itself (no network yet at login, bad reply).
    Timer {
        interval: 30000
        running: root.configured && root.cc === null && root.retryable
        onTriggered: root.loc === "" ? root.reload() : root.fetchForecast()
    }
}
