pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Current conditions and forecast from Open-Meteo (no API key). The location
// comes from IP geolocation unless a city is set (setCity, or
// `qs ipc call weather city Berlin`; an empty name goes back to auto). The
// last response is cached in the state dir so the bar has a reading right
// after a reload.
Singleton {
    id: root

    readonly property bool imperial: saved.units !== "" ? saved.units === "imperial"
        : Qt.locale().measurementSystem === Locale.ImperialUSSystem
    readonly property string windUnit: imperial ? "mph" : "km/h"

    property var data: null
    property bool loading: false
    property string error: ""
    readonly property bool ready: data !== null
    readonly property string place: saved.place
    readonly property bool autoLocation: saved.city === ""
    readonly property real fetched: saved.fetched   // ms epoch of `data`

    // ---------- derived ----------
    readonly property var current: {
        const c = data?.current;
        if (!c)
            return null;
        return {
            temp: c.temperature_2m,
            feels: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            dew: c.dew_point_2m,
            day: c.is_day === 1,
            code: c.weather_code,
            wind: c.wind_speed_10m,
            gusts: c.wind_gusts_10m,
            windDir: c.wind_direction_10m,
            uv: c.uv_index ?? 0,
            visibility: c.visibility,
            pressure: c.surface_pressure
        };
    }

    readonly property var hours: {
        const h = data?.hourly;
        if (!h)
            return [];
        return h.time.map((t, i) => ({
            time: t,
            label: i === 0 ? "Now" : t.slice(11, 13),
            temp: h.temperature_2m[i],
            code: h.weather_code[i],
            day: h.is_day[i] === 1,
            pop: h.precipitation_probability?.[i] ?? 0
        }));
    }

    // Hours with today's / tomorrow's sunrise and sunset slotted in, like iOS.
    readonly property var hourly: {
        if (hours.length === 0)
            return [];
        const events = [];
        for (const d of daily.slice(0, 2))
            events.push({ time: d.sunrise, sun: "sunrise" }, { time: d.sunset, sun: "sunset" });
        const out = [];
        hours.forEach((h, i) => {
            out.push(h);
            const next = hours[i + 1]?.time;
            if (!next)
                return;
            for (const e of events)
                if (e.time > h.time && e.time < next && (i > 0 || e.time > (data.current?.time ?? "")))
                    out.push({ label: e.time.slice(11), sun: e.sun });
        });
        return out;
    }

    // One-line outlook for the hourly card.
    readonly property string summary: {
        if (!current || hours.length === 0)
            return "";
        const next = hours.slice(1, 13);
        const fam = sky(current.code);
        const wet = next.find(h => h.pop >= 50);
        const change = next.find(h => sky(h.code) !== fam);
        let text = wet && fam !== "rain" && fam !== "snow" && fam !== "storm"
            ? `${sky(wet.code) === "snow" ? "Snow" : "Rain"} likely around ${wet.label}:00.`
            : change ? `${describe(change.code)} conditions expected around ${change.label}:00.`
            : `${describe(current.code)} conditions for the next hours.`;
        if (current.gusts >= 20)
            text += ` Wind gusts are up to ${Math.round(current.gusts)} ${windUnit}.`;
        return text;
    }

    readonly property var daily: {
        const d = data?.daily;
        if (!d)
            return [];
        return d.time.map((t, i) => {
            const p = t.split("-").map(Number);
            return {
                label: i === 0 ? "Today" : Qt.formatDate(new Date(p[0], p[1] - 1, p[2]), "ddd"),
                code: d.weather_code[i],
                hi: d.temperature_2m_max[i],
                lo: d.temperature_2m_min[i],
                pop: d.precipitation_probability_max?.[i] ?? 0,
                sunrise: d.sunrise[i],
                sunset: d.sunset[i],
                uvMax: d.uv_index_max?.[i] ?? 0
            };
        });
    }
    readonly property real weekMin: daily.reduce((m, d) => Math.min(m, d.lo), Infinity)
    readonly property real weekMax: daily.reduce((m, d) => Math.max(m, d.hi), -Infinity)

    readonly property string icon: current ? iconFor(current.code, current.day) : "cloud-off"
    readonly property string condition: current ? describe(current.code) : ""
    readonly property string tempText: current ? deg(current.temp) : "--"

    // ---------- sky palette, shared by the panel and the widgets ----------
    readonly property string skyFamily: current ? sky(current.code) : "cloudy"
    readonly property bool isDay: current?.day ?? true
    readonly property bool golden: {
        const t = daily[0];
        if (!current || !t || (skyFamily !== "clear" && skyFamily !== "partly"))
            return false;
        const now = minutes(data.current.time);
        return Math.abs(now - minutes(t.sunrise)) < 45 || Math.abs(now - minutes(t.sunset)) < 45;
    }
    readonly property bool foggy: current !== null && (current.code === 45 || current.code === 48)
    // [top, bottom, glow]
    readonly property var palette: {
        const fam = skyFamily;
        if (golden)
            return ["#34528f", "#e7896b", "#ffc27a"];
        if (isDay)
            return fam === "clear" ? ["#2b78d0", "#74aee6", "#fff1b8"]
                : fam === "partly" ? ["#3f74ad", "#86a9cc", "#fff1b8"]
                : foggy ? ["#6b7682", "#9aa3ad", "#ffffff"]
                : fam === "cloudy" ? ["#56677a", "#8595a6", "#ffffff"]
                : fam === "rain" ? ["#3b4d61", "#5f7287", "#ffffff"]
                : fam === "storm" ? ["#262a40", "#4a4566", "#ffe9a8"]
                : ["#7a90a8", "#b3c3d3", "#ffffff"];
        return fam === "clear" ? ["#0a1430", "#22366a", "#cfd8ff"]
            : fam === "partly" ? ["#121c35", "#2d3b5e", "#cfd8ff"]
            : fam === "rain" ? ["#151c28", "#2c3646", "#ffffff"]
            : fam === "storm" ? ["#16182a", "#33304d", "#ffe9a8"]
            : fam === "snow" ? ["#28324a", "#4a5670", "#ffffff"]
            : ["#1a212e", "#343d4e", "#ffffff"];
    }

    // minutes since midnight of an ISO local time ("2026-11-05T16:49")
    function minutes(iso: string): int {
        return iso.length >= 16 ? parseInt(iso.slice(11, 13)) * 60 + parseInt(iso.slice(14, 16)) : 0;
    }

    // Colour for a temperature, cold blue → green → yellow → hot red (iOS bars).
    function tempColor(t: real): color {
        const c = imperial ? (t - 32) * 5 / 9 : t;
        const stops = [[-10, 0.24, 0.49, 0.96], [0, 0.35, 0.78, 0.98], [10, 0.49, 0.84, 0.65],
            [18, 1, 0.84, 0.04], [26, 1, 0.62, 0.04], [34, 1, 0.27, 0.23]];
        let i = 1;
        while (i < stops.length - 1 && c > stops[i][0])
            i++;
        const a = stops[i - 1], b = stops[i];
        const f = Math.max(0, Math.min(1, (c - a[0]) / (b[0] - a[0])));
        return Qt.rgba(a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, 1);
    }

    // Lucide glyphs are single-colour, so tint the ones iOS draws in colour.
    function iconColor(code: int, day: bool): color {
        return code <= 1 ? (day ? "#ffd60a" : "#e8ecff") : code >= 95 ? "#ffe066" : "#ffffff";
    }

    readonly property color rainColor: "#64d2ff"

    function deg(v: real): string {
        return Math.round(v) + "°";
    }

    // WMO weather interpretation codes
    function describe(code: int): string {
        switch (code) {
        case 0: return "Clear";
        case 1: return "Mostly Clear";
        case 2: return "Partly Cloudy";
        case 3: return "Overcast";
        case 45: case 48: return "Fog";
        case 51: case 53: case 55: return "Drizzle";
        case 56: case 57: return "Freezing Drizzle";
        case 61: return "Light Rain";
        case 63: return "Rain";
        case 65: return "Heavy Rain";
        case 66: case 67: return "Freezing Rain";
        case 71: return "Light Snow";
        case 73: return "Snow";
        case 75: return "Heavy Snow";
        case 77: return "Snow Grains";
        case 80: case 81: return "Showers";
        case 82: return "Heavy Showers";
        case 85: case 86: return "Snow Showers";
        case 95: return "Thunderstorm";
        case 96: case 99: return "Hailstorm";
        }
        return "Unknown";
    }

    function iconFor(code: int, day: bool): string {
        switch (code) {
        case 0: case 1: return day ? "sun" : "moon";
        case 2: return day ? "cloud-sun" : "cloud-moon";
        case 3: return "cloudy";
        case 45: case 48: return "cloud-fog";
        case 51: case 53: case 55: case 56: case 57: return "cloud-drizzle";
        case 61: case 63: return "cloud-rain";
        case 65: case 82: return "cloud-rain-wind";
        case 66: case 67: case 96: case 99: return "cloud-hail";
        case 71: case 73: case 75: case 85: case 86: return "cloud-snow";
        case 77: return "snowflake";
        case 80: case 81: return day ? "cloud-sun-rain" : "cloud-moon-rain";
        case 95: return "cloud-lightning";
        }
        return "cloud";
    }

    // Rough sky family, used to dress the panel backdrop.
    function sky(code: int): string {
        return code <= 1 ? "clear" : code === 2 ? "partly" : code === 3 || code === 45 || code === 48 ? "cloudy"
            : code >= 95 ? "storm" : (code >= 71 && code <= 77) || code === 85 || code === 86 ? "snow" : "rain";
    }

    function uvLevel(uv: real): string {
        return uv < 3 ? "Low" : uv < 6 ? "Moderate" : uv < 8 ? "High" : uv < 11 ? "Very High" : "Extreme";
    }

    function compass(dir: real): string {
        return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(dir / 45) % 8];
    }

    // ---------- fetching ----------
    property real startedAt: 0

    function refresh(): void {
        // the timeout is a guard against a request whose output never arrives
        if (loading && Date.now() - startedAt < 30000)
            return;
        loading = true;
        startedAt = Date.now();
        error = "";
        if (saved.city === "") {
            geoIp.running = true;
        } else if (saved.resolved === saved.city && (saved.lat !== 0 || saved.lon !== 0)) {
            fetchForecast();
        } else {
            geocode.query = saved.city;
            geocode.running = true;
        }
    }

    function setCity(name: string): void {
        name = name.trim();
        if (name === saved.city && (name === "" || saved.resolved === name))
            return;
        saved.city = name;
        saved.resolved = "";
        saved.lat = 0;
        saved.lon = 0;
        saved.place = "";
        savedFile.writeAdapter();
        loading = false;
        geoIp.running = false;
        geocode.running = false;
        forecast.running = false;
        refresh();
    }

    function setUnits(units: string): void {
        saved.units = units;
        savedFile.writeAdapter();
        loading = false;
        refresh();
    }

    function fail(msg: string): void {
        loading = false;
        error = msg;
        retry.restart();
    }

    function locate(lat: real, lon: real, name: string): void {
        saved.lat = lat;
        saved.lon = lon;
        saved.place = name;
        saved.resolved = saved.city;
        savedFile.writeAdapter();
        fetchForecast();
    }

    function fetchForecast(): void {
        const q = [
            `latitude=${saved.lat}`, `longitude=${saved.lon}`, "timezone=auto",
            "current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,is_day,weather_code,"
                + "wind_speed_10m,wind_gusts_10m,wind_direction_10m,uv_index,visibility,surface_pressure",
            "hourly=temperature_2m,weather_code,is_day,precipitation_probability",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max",
            "forecast_days=7", "forecast_hours=25"
        ];
        if (imperial)
            q.push("temperature_unit=fahrenheit", "wind_speed_unit=mph");
        forecast.lat = saved.lat;
        forecast.lon = saved.lon;
        forecast.command = ["curl", "-sf", "-m", "15", "https://api.open-meteo.com/v1/forecast?" + q.join("&")];
        forecast.running = true;
    }

    function apply(text: string): bool {
        try {
            const d = JSON.parse(text);
            if (!d.current)
                return false;
            data = d;
            return true;
        } catch (e) {
            return false;
        }
    }

    Process {
        id: geoIp
        command: ["curl", "-sf", "-m", "10", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (saved.city !== "")
                    return;   // a city was picked while this was in flight
                try {
                    const j = JSON.parse(text);
                    const [lat, lon] = j.loc.split(",").map(Number);
                    root.locate(lat, lon, j.city ?? "");
                } catch (e) {
                    // offline or rate-limited: fall back to the last known spot
                    if (saved.lat !== 0 || saved.lon !== 0)
                        root.fetchForecast();
                    else
                        root.fail("Couldn't find your location");
                }
            }
        }
    }

    Process {
        id: geocode
        property string query
        command: ["curl", "-sf", "-m", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search",
            "--data-urlencode", "name=" + query, "-d", "count=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (geocode.query !== saved.city)
                    return;
                try {
                    const r = JSON.parse(text).results[0];
                    root.locate(r.latitude, r.longitude, r.name);
                } catch (e) {
                    root.fail(`No place called “${saved.city}”`);
                }
            }
        }
    }

    Process {
        id: forecast
        property real lat
        property real lon
        stdout: StdioCollector {
            onStreamFinished: {
                if (forecast.lat !== saved.lat || forecast.lon !== saved.lon)
                    return;   // the location changed meanwhile
                if (!root.apply(text))
                    return root.fail("Weather service unavailable");
                saved.cache = text;
                saved.fetched = Date.now();
                savedFile.writeAdapter();
                root.loading = false;
            }
        }
    }

    // ---------- schedule ----------
    Timer {
        interval: 15 * 60 * 1000
        running: root.started
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        id: retry
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    FileView {
        id: savedFile
        path: Quickshell.statePath("weather.json")
        blockLoading: true
        printErrors: false
        // start only once the saved city is known, or a startup refresh
        // falls back to IP location and overwrites it
        onLoaded: root.init()
        onLoadFailed: root.init()
        JsonAdapter {
            id: saved
            property string city: ""      // user override; "" = IP location
            property string resolved: ""  // the `city` that lat / lon belong to
            property string units: ""     // "metric" | "imperial"; "" = from locale
            property string place: ""
            property real lat: 0
            property real lon: 0
            property string cache: ""
            property real fetched: 0
        }
    }

    property bool started: false

    function init(): void {
        if (started)
            return;
        started = true;
        apply(saved.cache);
        refresh();
    }

    IpcHandler {
        target: "weather"

        function refresh(): void {
            root.refresh();
        }
        function city(name: string): void {
            root.setCity(name);
        }
        function units(units: string): void {
            root.setUnits(units);
        }
    }
}
