const VectorCoordsType = Vector{<:Vector{<:Number}}

abstract type PointsSeries{N, T} end
function (::Type{T})(vec::VectorCoordsType) where {T <: PointsSeries}
    # npoints = length(vec)
    T(Tuple(Tuple.(vec)))
end
# function (::Type{T})(args...) where {T <: PointsSeries}
#     T(Tuple(Tuple.(args)))
# end
coords(ps::PointsSeries) = ps.coords

abstract type AbstractReleaseLocation{N, T} <: PointsSeries{N, T} end
GI.isgeometry(geom::AbstractReleaseLocation)::Bool = true
GI.geomtrait(::AbstractReleaseLocation) = MultiPointTrait()
GI.ngeom(::MultiPointTrait, ::AbstractReleaseLocation{N, T}) where {N, T} = N
GI.getgeom(::MultiPointTrait, geom::AbstractReleaseLocation, i) = coords(geom)[i]

"""
    ReleaseLocation{N, T}
Represents the `N` locations of the release(s).

# Examples
```julia-repl
# We create a triangle like border (3 vertices):
julia> coords = [
    [6., 49.],
    [6., 51.],
]
julia> ReleaseLocation(coords)
ReleaseLocation{2, Float64}(((6.0, 49.0), (6.0, 51.0)))
```
"""
struct ReleaseLocation{N, T} <: AbstractReleaseLocation{N, T}
    coords::NTuple{N, NTuple{2, T}}
end

"""
    ZoneBoundary{N, T}
Represents the border for a ATP45 zone. `N` is the number of vertices defining the zone.

# Examples
```julia-repl
# We create a triangle like border (3 vertices):
julia> coords = [
    [6., 49.],
    [5., 50.],
    [4., 49.],
]
julia> ZoneBoundary(coords)
ZoneBoundary{3, Float64}(((6.0, 49.0), (5.0, 50.0), (4.0, 49.0)))
```
"""
struct ZoneBoundary{N, T} <: PointsSeries{N, T} 
    coords::NTuple{N, NTuple{2, T}}
end
GI.isgeometry(::ZoneBoundary)::Bool = true
GI.geomtrait(::ZoneBoundary) = LinearRingTrait()

# We add the first point add the end to make it a closed shape.
GI.ngeom(::LinearRingTrait, geom::ZoneBoundary{N, T}) where {N, T} = N + 1
GI.getgeom(::LinearRingTrait, geom::ZoneBoundary{N, T}, i) where {N, T} = coords(geom)[(i-1)%N + 1]


abstract type AbstractZone{N, T} end

GI.isgeometry(geom::AbstractZone)::Bool = true
GI.geomtrait(::AbstractZone) = PolygonTrait()
GI.ngeom(::PolygonTrait, ::AbstractZone) = 1
GI.getgeom(::PolygonTrait, zone::AbstractZone, i) = geometry(zone)

"""
    Zone{N, T} <: AbstractZone{N, T}
Defines a closed polygon with `N` vertices for representing a ATP-45 zone.
"""
struct Zone{N, T} <: AbstractZone{N, T}
    geometry::ZoneBoundary{N, T}
end
geometry(zone::Zone) = zone.geometry
Zone(vec::VectorCoordsType) = Zone(ZoneBoundary(vec))
Zone(args...) = Zone(ZoneBoundary(args...))

"""
    AbstractZoneFeature{N, T}
An ATP-45 zone with some properties related to it.
"""
abstract type AbstractZoneFeature{N, T} end
# geometry(zonefeature::AbstractZoneFeature) = zonefeature.geometry
properties(zonefeature::AbstractZoneFeature) = zonefeature.properties
GI.isfeature(::Type{<:AbstractZoneFeature}) = true
GI.trait(::AbstractZoneFeature) = FeatureTrait()
GI.properties(zonefeature::AbstractZoneFeature) = properties(zonefeature)

struct TriangleLike{T} <: AbstractZoneFeature{3, T}
    geometry::Zone{3, T}
    properties::Dict{String, String}
    # function TriangleLike(x::Vector{<:Vector{<:T}}, y) where T<:Number
    #     push!(x, x[1])
    #     new(x, y)
    # end
end
function TriangleLike(releaselocation::ReleaseLocation{1, T}, wind::AbstractWind, dhd, back_distance, props = Dict()) where T
    azimuth = wind_azimuth(wind)
    center = coords(releaselocation)[1]
    triangle_coords = triangle_coordinates(center..., T(azimuth), T(dhd), T(back_distance))
    TriangleLike{T}(Zone(triangle_coords), props)
end
GI.geometry(triangle::TriangleLike) = triangle.geometry

struct CircleLike{N, T} <: AbstractZoneFeature{N, T}
    center::ReleaseLocation{1, T}
    radius::T
    properties::Dict{String, String}
end

function CircleLike(releaselocation::ReleaseLocation{1, T}, radius::Number, props = Dict(); numpoint = 100) where {T}
    CircleLike{numpoint, T}(releaselocation, radius, props)
end

function GI.geometry(circle::CircleLike{N, T}) where {N, T}
    center = coords(circle.center)[1]
    circle_coords = circle_coordinates(center..., circle.radius; res = N)
    Zone(circle_coords)
end
# GI.ngeom(::TriangleTrait, geom::TriangleLike)::Integer = 1
# GI.getgeom(::TriangleTrait, geom::TriangleLike, i) = geom.geom
# GeoInterface.ngeom(::TriangleLike)::DataType = TriangleTrait()