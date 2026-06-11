local DEBUG = false

local worldTime = 480
local DAY_LENGTH_SECONDS = 300
local MINUTES_PER_DAY = 1440
local TWO_PI = math.pi * 2

local currentWeather = {
    type = "Clear",
    intensity = 0,
    transition = 1,
    duration = 30,
}

local targetWeather = nil

local lightningCooldown = 0
local lightningFlash = 0
local lightningDuration = 0
local thunderDelay = 0

local baseDirection = nil
local baseSpeed = 0.2
local gustStrength = 0
local windTurbulence = 0.1
local windTime = 0

local function rand(min, max)
    return min + (max - min) * math.random()
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function LerpColor(a, b, t)
    return {
        r = Lerp(a.r, b.r, t),
        g = Lerp(a.g, b.g, t),
        b = Lerp(a.b, b.b, t),
    }
end

local function normalize(v)
    local m = math.sqrt(v.x * v.x + v.y * v.y)
    if m == 0 then
        return { x = 1, y = 0 }
    end
    return { x = v.x / m, y = v.y / m }
end

local function oscillate(t, speed, amp)
    return math.sin(t * speed) * amp
end

local NIGHT_ZENITH = { r = 5, g = 10, b = 25 }
local NIGHT_HORIZON = { r = 20, g = 30, b = 60 }
local DAY_ZENITH = { r = 135, g = 100, b = 255 }
local DAY_HORIZON = { r = 200, g = 220, b = 255 }
local SUNSET_ZENITH = { r = 255, g = 140, b = 90 }
local SUNSET_HORIZON = { r = 255, g = 90, b = 60 }

local WEATHER_DURATION = {
    Clear = { 20, 60 },
    Cloudy = { 30, 90 },
    Foggy = { 40, 90 },
    Rain = { 25, 60 },
    Storm = { 20, 40 },
}

local function updateWorldTime(dt)
    local minutesPerSecond = MINUTES_PER_DAY / DAY_LENGTH_SECONDS
    worldTime = (worldTime + minutesPerSecond * dt) % MINUTES_PER_DAY
end

local function getDayFraction()
    return worldTime / MINUTES_PER_DAY
end

local function getSolarElevation()
    local t = getDayFraction()
    local angle = math.sin((t * TWO_PI) - math.pi / 2)
    return math.clamp(angle, -1, 1)
end

local function getSolarAzimuth()
    local t = getDayFraction()
    return (t * TWO_PI) % TWO_PI
end

local function getSolarState()
    return {
        timeMinutes = worldTime,
        dayFraction = getDayFraction(),
        elevation = getSolarElevation(),
        azimuth = getSolarAzimuth(),
    }
end

local function getSkyGradient(elevation)
    local t = (elevation + 1) / 2
    local sunsetStrength = math.max(0, 1 - math.abs(elevation * 3))

    local zenith = LerpColor(NIGHT_ZENITH, DAY_ZENITH, t)
    local horizon = LerpColor(NIGHT_HORIZON, DAY_HORIZON, t)

    local zenithFinal = LerpColor(zenith, SUNSET_ZENITH, sunsetStrength)
    local horizonFinal = LerpColor(horizon, SUNSET_HORIZON, sunsetStrength)

    return {
        zenith = zenithFinal,
        horizon = horizonFinal,
        sunsetStrength = sunsetStrength,
    }
end

local function getAtmosphereState(elevation, sky)
    local dayT = math.clamp((elevation + 0.1) * 1.2, 0, 1)

    local fogDensity = Lerp(0.02, 0.15, 1 - dayT) + sky.sunsetStrength * 0.05
    local fogColor = LerpColor(sky.horizon, sky.zenith, 0.3)
    local ambient = LerpColor({ r = 10, g = 10, b = 20 }, sky.horizon, dayT)
    local exposure = Lerp(0.5, 1.3, dayT)

    return {
        ambient = ambient,
        fogColor = fogColor,
        fogDensity = fogDensity,
        exposure = exposure,
    }
end

local function computeIntensity(t, x)
    if t == "Clear" then
        return 1 - x * 0.5
    end
    if t == "Cloudy" then
        return x * 0.6
    end
    if t == "Foggy" then
        return x * 0.9
    end
    if t == "Rain" then
        return x * 1.0
    end
    if t == "Storm" then
        return x * 1.0
    end
    return 0
end

local function chooseWeather()
    local r = math.random()
    if r < 0.5 then
        return "Clear"
    end
    if r < 0.75 then
        return "Cloudy"
    end
    if r < 0.85 then
        return "Foggy"
    end
    if r < 0.95 then
        return "Rain"
    end
    return "Storm"
end

local function startWeatherTransition(newType)
    local range = WEATHER_DURATION[newType]
    targetWeather = {
        type = newType,
        intensity = 0,
        transition = 0,
        duration = rand(range[1], range[2]),
    }
end

local function updateWeather(dt)
    if not targetWeather then
        startWeatherTransition(chooseWeather())
        return
    end

    targetWeather.transition = math.min(1, targetWeather.transition + dt * 0.08)
    targetWeather.intensity = computeIntensity(targetWeather.type, targetWeather.transition)

    if targetWeather.transition >= 1 then
        currentWeather = targetWeather
        targetWeather = nil
        return
    end

    currentWeather.duration -= dt
    if currentWeather.duration <= 0 and not targetWeather then
        startWeatherTransition(chooseWeather())
    end
end

local function getWeatherState()
    return {
        current = currentWeather,
        target = targetWeather,
    }
end

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

local function computeWeatherDensity(t, i)
    if t == "Clear" then
        return 0.1 * (1 - i)
    end
    if t == "Cloudy" then
        return 0.4 + i * 0.4
    end
    if t == "Foggy" then
        return 0.3 + i * 0.2
    end
    if t == "Rain" then
        return 0.6 + i * 0.3
    end
    if t == "Storm" then
        return 0.8 + i * 0.2
    end
    return 0
end

local function computeCloudColor(sky, weather)
    local base = LerpColor(sky.horizon, sky.zenith, 0.4)

    if weather.type == "Storm" then
        base = LerpColor(base, { r = 40, g = 40, b = 50 }, weather.intensity)
    end

    if sky.sunsetStrength > 0.1 then
        base = LerpColor(base, { r = 255, g = 120, b = 80 }, sky.sunsetStrength * 0.6)
    end

    return base
end

local function computeCloudHeight(w)
    if w.type == "Clear" then
        return 0.9
    end
    if w.type == "Cloudy" then
        return 0.8
    end
    if w.type == "Foggy" then
        return 0.6
    end
    if w.type == "Rain" then
        return 0.7
    end
    if w.type == "Storm" then
        return 0.5
    end
    return 0.8
end

local function computeCloudSpeed(w)
    if w.type == "Clear" then
        return 0.2
    end
    if w.type == "Cloudy" then
        return 0.35
    end
    if w.type == "Foggy" then
        return 0.12
    end
    if w.type == "Rain" then
        return 0.45
    end
    if w.type == "Storm" then
        return 0.75
    end
    return 0.2
end

local function computeCloudTurbulence(w)
    if w.type == "Clear" then
        return 0.05
    end
    if w.type == "Cloudy" then
        return 0.15
    end
    if w.type == "Foggy" then
        return 0.1
    end
    if w.type == "Rain" then
        return 0.25
    end
    if w.type == "Storm" then
        return 0.6
    end
    return 0.1
end

local function getCloudState(elev, sky, weather)
    local density = math.clamp(computeWeatherDensity(weather.type, weather.intensity), 0, 1)
    local thickness = smoothstep(density)
    local speed = computeCloudSpeed(weather)
    local color = computeCloudColor(sky, weather)
    local height = computeCloudHeight(weather)
    local turbulence = computeCloudTurbulence(weather)

    return {
        density = density,
        thickness = thickness,
        speed = speed,
        color = color,
        height = height,
        turbulence = turbulence,
    }
end

local function computeBaseSpeed(w)
    if w.type == "Clear" then
        return 0.12 + w.intensity * 0.1
    end
    if w.type == "Cloudy" then
        return 0.22 + w.intensity * 0.2
    end
    if w.type == "Foggy" then
        return 0.16 + w.intensity * 0.1
    end
    if w.type == "Rain" then
        return 0.32 + w.intensity * 0.3
    end
    if w.type == "Storm" then
        return 0.65 + w.intensity * 0.45
    end
    return 0.2
end

local function computeTurbulence(w)
    if w.type == "Clear" then
        return 0.05
    end
    if w.type == "Cloudy" then
        return 0.1
    end
    if w.type == "Foggy" then
        return 0.08
    end
    if w.type == "Rain" then
        return 0.22
    end
    if w.type == "Storm" then
        return 0.55
    end
    return 0.1
end

local function updateWind(dt, weather)
    windTime += dt

    local sx = oscillate(windTime, 0.05, 0.3)
    local sy = oscillate(windTime, 0.04, 0.3)

    baseDirection = normalize({
        x = baseDirection.x + sx * dt,
        y = baseDirection.y + sy * dt,
    })

    baseSpeed = computeBaseSpeed(weather)
    gustStrength = math.max(0, oscillate(windTime, 1.5, 1) * computeTurbulence(weather))
    windTurbulence = computeTurbulence(weather)
end

local function getWindState()
    return {
        direction = baseDirection,
        speed = baseSpeed,
        gust = gustStrength,
        turbulence = windTurbulence,
    }
end

local function computeRainState(weather, wind)
    local base = 0
    if weather.type == "Rain" or weather.type == "Storm" then
        base = weather.intensity
    end

    local intensity = math.min(1, base)
    local dropletSpeed = math.min(1, intensity * 0.6 + wind.speed * 0.4)

    return {
        intensity = intensity,
        direction = wind.direction,
        dropletSpeed = dropletSpeed,
        splashIntensity = intensity * 0.8,
    }
end

local function lightningChance(weather)
    if weather.type ~= "Storm" then
        return 0
    end
    return 0.05 + weather.intensity * 0.25
end

local function triggerLightning()
    lightningFlash = 1
    lightningDuration = 0.15 + math.random() * 0.2
    thunderDelay = 0.5 + math.random() * 2.5
    lightningCooldown = 1 + math.random() * 2
end

local function updateLightning(dt, weather)
    if lightningCooldown > 0 then
        lightningCooldown -= dt
    else
        if math.random() < lightningChance(weather) * dt then
            triggerLightning()
        end
    end

    if lightningFlash > 0 then
        lightningFlash -= dt * (1 / lightningDuration)
        if lightningFlash < 0 then
            lightningFlash = 0
        end
    end

    if thunderDelay > 0 then
        thunderDelay -= dt
        if thunderDelay < 0 then
            thunderDelay = 0
        end
    end
end

local function getLightningState()
    return {
        active = lightningFlash > 0,
        brightness = lightningFlash,
        duration = lightningDuration,
        thunderDelay = thunderDelay,
    }
end

local function getRainAndLightningState(dt, weather, wind)
    updateLightning(dt, weather)
    return {
        rain = computeRainState(weather, wind),
        lightning = getLightningState(),
    }
end

local function init()
    if not baseDirection then
        baseDirection = normalize({ x = rand(-1, 1), y = rand(-1, 1) })
    end
end

local function updateWorld(dt)
    init()
    updateWorldTime(dt)
    local solar = getSolarState()

    updateWeather(dt)
    local weatherState = getWeatherState()

    updateWind(dt, weatherState.current)
    local windState = getWindState()

    local sky = getSkyGradient(solar.elevation)
    local atmosphere = getAtmosphereState(solar.elevation, sky)
    local clouds = getCloudState(solar.elevation, sky, weatherState.current)
    local rainLightning = getRainAndLightningState(dt, weatherState.current, windState)

    return {
        time = solar,
        sky = sky,
        atmosphere = atmosphere,
        weather = weatherState,
        clouds = clouds,
        wind = windState,
        rain = rainLightning.rain,
        lightning = rainLightning.lightning,
    }
end

local function forceWeather(newType)
    local range = WEATHER_DURATION[newType] or { 30, 60 }
    currentWeather = {
        type = newType,
        intensity = 1,
        transition = 1,
        duration = rand(range[1], range[2]),
    }
    targetWeather = nil
end

return {
    updateWorld = updateWorld,
    forceWeather = forceWeather,
}

--Author and owner: Taco (@Ax_Atomic) RBLX
--compiled via Rojo RbxTS from typescript
--Any questions or comments, @nova_lmao on discord.
