abstract type AbstractStability end
ParamType(::Type{<:AbstractStability}) = Meteo()

struct Unstable <: AbstractStability end
id(::Type{Unstable}) = "unstable"
longname(::Type{Unstable}) = "Unstable"

struct Neutral <: AbstractStability end
id(::Type{Neutral}) = "neutral"
longname(::Type{Neutral}) = "Neutral"

struct Stable <: AbstractStability end
id(::Type{Stable}) = "stable"
longname(::Type{Stable}) = "Stable"

abstract type AbstractWind end
ParamType(::Type{<:AbstractWind}) = Meteo()

"""
    WindVector(u, v) <: AbstractWind
Defines the wind with its horizontal coordinates. `u` is W-E and `v` is S-N.
"""
mutable struct WindVector <: AbstractWind
    u::Real
    v::Real
end
==(w1::WindVector, w2::WindVector) = w1.u == w2.u && w1.v == w2.v

"""
    WindDirection(speed, azimuth) <: AbstractWind
Defines the wind with its `speed` in m/s and its `azimuth` in degrees (with North as reference).
"""
mutable struct WindDirection <: AbstractWind
    speed::Real
    direction::Real
end
==(w1::WindDirection, w2::WindDirection) = w1.speed == w2.speed && w1.direction == w2.direction

function _2windvector(wind::WindDirection)
    u = wind.speed*cosd(90 - wind.direction)
    v = wind.speed*sind(90 - wind.direction)
    return u, v
end

function _2winddir(wind::WindVector)
    dir = wind_azimuth(wind.u, wind.v)
    speed = wind_speed(wind)
    return speed, dir
end

function wind_speed(Vx, Vy)
    return sqrt(Vx^2 + Vy^2)
end

wind_speed(wind::WindVector) = wind_speed(wind.u, wind.v)
function wind_speed(wind::WindDirection)
    WindVector = _2windvector(wind)
    wind_speed(WindVector[1], WindVector[2])
end

function wind_azimuth(Vx, Vy)
    return 90. - atan(Vy, Vx) * 180 / π
end

function wind_azimuth(lon1, lat1, lon2, lat2)
    x = cosd(lat1)*sind(lat2) - sind(lat1)*cosd(lat2)*cosd(lon2 - lon1)
    y = sind(lon2 - lon1)*cosd(lat2)
    return 2*atand(y/(sqrt(x^2 + y^2) + x))
end

wind_azimuth(wind::WindVector) = convert(WindDirection, wind).direction
wind_azimuth(wind::WindDirection) = wind.direction

function Base.convert(::Type{WindDirection}, w::WindVector)
    WindDirection(_2winddir(w)...)
end

function Base.convert(::Type{WindVector}, w::WindDirection)
    WindVector(_2windvector(w)...)
end