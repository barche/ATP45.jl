mutable struct Atp45Input
    "Vector of locations in format [lon, lat]"
    locations::Vector{Vector{Real}}
    "Information about the wind"
    wind::AbstractWind
    "Type of containers"
    container::Symbol
    "Type of procedure"
    procedure::Symbol
    "Stability Class"
    stab::StabilityClass
end

mutable struct Atp45Result
    "Coordinates of the multiple Atp45 model areas"
    collection::FeatureCollection
    "Input used for the model"
    input::Atp45Input
end



"""
    run_chem(input)

Calculate the release and hazard area according to the case we want, for a chemical incident (Page 3-1)
"""
function run_chem(input::Atp45Input)
    #result::FeatureCollection = foo()
    if input.procedure == :A                     # Page 3-15 and 3-16, Type A, Cases 1 and 2
        if input.stab == Unstable
            if CONTAINERS[input.container][:stab] == 10                     
                Atp45Result(proc(input, 10000., 1000., 10000.), input)
            elseif CONTAINERS[input.container][:stab] == 15
                Atp45Result(proc(input, 15000., 1000., 10000.), input)
            end
        elseif input.stab == Neutral
            Atp45Result(proc(input, 30000., 1000., 10000.), input)
        elseif input.stab == Stable
            Atp45Result(proc(input, 50000., 1000., 10000.), input)
        end
    elseif input.procedure == :B                 # Page 3-18 to 3-25, Type B, all cases
        Atp45Result(typeB(input), input)
    elseif input.procedure == :C                 # Page 3-26, Type C, Cases 1 and 2
        Atp45Result(Unobserved(input, 10000.), input)
    elseif input.procedure == :simplified        # Page 3-7 to 3-9, Simplified Procedure, Cases 1 and 2
        Atp45Result(proc(input, 10000., 2000., 10000.), input)
    else
        error("The procedure type $(input.procedure) is not recognized")
    end
end
# There is a type D not implemented yet because it depends on the chemical substance released
#All infos Page 3-34



"""
    run_bio(input)

Calculate the release and hazard area according to the case we want, for a biological incident (Page 4-1)
"""
function run_bio(input::Atp45Input)
    if input.procedure == :simplified
        Atp45Result(proc(input, 10000., 2000., 10000.), input)
    elseif input.procedure == :P
        Atp45Result(proc(input, 10000., 2000., 20000.), input)
    elseif input.procedure == :Q
        Atp45Result(proc(input, 10000., 10000., 20000.), input)
    elseif input.procedure == :R
        # NOT WORKING
        Atp45Result(typeB_2(input, 2000., res), input)
    elseif input.procedure == :C
        Atp45Result(Unobserved(input, 50000.), input)
    else
        error("The procedure type $(input.procedure) is not recognized")
    end
end


#TODO: implementation of radiological and nuclear incident with run_radio and run_nucl (Page 5-1 and 6-1)

"""
    circle_area(lon::Number, lat::Number, radius::Number, res)

Calculate the coordinates of the release or the hazard area (circle)
"""
function circle_area(lon::Number, lat::Number, radius::Number, res = 360)
    azimuth = range(0., 360., length = res)
    coords = []
    for az in azimuth
        push!(coords, horizontal_walk(lon, lat, radius, az))
    end
    return coords
end



"""
    hazard_area_triangle(lon, lat, Vx, Vy, hauteur, radius)

Calculate the coordinates of the ends of the hazard area (a triangle) in the case of a wind speed > 10km/h
"""
function hazard_area_triangle(lon, lat, Vx, Vy, dist, radius)
    l = dist/cosd(30)
    coords = []
    push!(coords, horizontal_walk(lon, lat, -2*radius, wind_direction(Vx, Vy)))
    push!(coords, horizontal_walk(coords[1][1], coords[1][2], l, wind_direction(Vx, Vy) - 30.))
    push!(coords, horizontal_walk(coords[1][1], coords[1][2], l, wind_direction(Vx, Vy) + 30.))
    return coords
end

hazard_area_triangle(lon, lat, wind::WindVector, dist, radius) = hazard_area_triangle(lon, lat, wind.u, wind.v, dist, radius)
function hazard_area_triangle(lon, lat, wind::WindDirection, dist, radius)
    WindVector = _2windvector(wind)
    hazard_area_triangle(lon, lat, WindVector[1], WindVector[2], dist, radius)
end



"""
Page 3-24 and 3-25 in NATO ATP-45: Warning  and Reporting and Hazard Prediction of CBRN Incidents (Operators Manual)

Type B, Case 5/6 of the detailled procedures
"""
function typeB_2(input::Atp45Input, radius, res = 360)
    lon1 = input.locations[1][1]
    lat1 = input.locations[1][2]
    lon2 = input.locations[2][1]
    lat2 = input.locations[2][2]

    release_area1 = circle_area(lon1, lat1, radius, res)
    release_area2 = circle_area(lon2, lat2, radius, res)

    az = Int(round(wind_direction(lon1, lat1, lon2, lat2)))
    if az < 0
        az += 360
    end

    if az <= 90
        coords_release = [vcat([release_area1[az + 90:az + 270]]..., [release_area2[az + 270:end]]..., [release_area2[1:az + 90]]...)]
    elseif 90 < az <= 270
        coords_release = [vcat([release_area1[az + 90:end]]..., [release_area1[1:az - 90]]..., [release_area2[az - 90:az + 90]]...)]
    else
        coords_release = [vcat([release_area1[az - 270:az - 90]]..., [release_area2[az - 90:end]]..., [release_area2[1:az - 270]]...)]
    end

    release_area = Polygon(coordinates = coords_release)
    prop1 = Dict("type" => "release", "shape" => "circles")
    feature = [Feature(release_area, prop1)]

    if wind_speed(input.wind) <= 10
        hazard_area1 = circle_area(lon1, lat1, 10000., res)
        hazard_area2 = circle_area(lon2, lat2, 10000., res)  
        if az <= 90
            coords_hazard = [vcat([hazard_area1[az + 90:az + 270]]..., [hazard_area2[az + 270:end]]..., [hazard_area2[1:az + 90]]...)]
        elseif 90 < az <= 270
            coords_hazard = [vcat([hazard_area1[az + 90:end]]..., [hazard_area1[1:az - 90]]..., [hazard_area2[az - 90:az + 90]]...)]
        else
            coords_hazard = [vcat([hazard_area1[az - 270:az - 90]]..., [hazard_area2[az - 90:end]]..., [hazard_area2[1:az - 270]]...)]
        end

        hazard_area = Polygon(coordinates = coords_hazard)
        prop2 = Dict("type" => "hazard", "shape" => "circles")
        push!(feature, Feature(hazard_area, prop2))
    else
        if az <= 180
            hazard_triangle1 = hazard_area_triangle(lon1, lat1, input.wind, 10000., 1000.)
            hazard_triangle2 = hazard_area_triangle(lon2, lat2, input.wind, 10000., 1000.)
        else
            hazard_triangle1 = hazard_area_triangle(lon2, lat2, input.wind, 10000., 1000.)
            hazard_triangle2 = hazard_area_triangle(lon1, lat1, input.wind, 10000., 1000.)
        end

        if az <= 45 || 180 <= az <= 225
            if input.wind.azimuth <= 45
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle1[3]])]
            elseif 45 < input.wind.azimuth <= 135
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[3]], [reverse(hazard_triangle2)...])]
            elseif 135 < input.wind.azimuth <= 180
                coords = [vcat([hazard_triangle2[1]], [hazard_triangle2[2]], [hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 180 < input.wind.azimuth <= 225
                coords = [vcat([hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle2[3]], [hazard_triangle2[1]], [hazard_triangle2[2]])]
            elseif 225 < input.wind.azimuth <= 270
                coords = [vcat([hazard_triangle1]..., [hazard_triangle2[3]], [hazard_triangle2[1]])]
            else
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle2[1]])]
            end

        elseif 45 < az <= 90 || 225 <= az <= 270
            if input.wind.azimuth <= 45
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle2[1]])]
            elseif 45 < input.wind.azimuth <= 90
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle1[3]])]
            elseif 90 < input.wind.azimuth <= 180
                coords = [vcat([hazard_triangle2]..., [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 180 < input.wind.azimuth <= 225
                coords = [vcat([hazard_triangle2[1]], [hazard_triangle2[2]], [hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 225 < input.wind.azimuth <= 270
                coords = [vcat([hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle2[3]], [hazard_triangle2[1]], [hazard_triangle2[2]])]
            else
                coords = [vcat([hazard_triangle1]..., [hazard_triangle2[3]], [hazard_triangle2[1]])]
            end

        elseif 90 < az <= 135 || 270 <= az <= 315
            if input.wind.azimuth <= 90
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle2[1]])]
            elseif 90 < input.wind.azimuth <= 135
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle1[3]])]
            elseif 135 < input.wind.azimuth <= 225
                coords = [vcat([hazard_triangle2]..., [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 225 <= input.wind.azimuth <= 270
                coords = [vcat([hazard_triangle2[1]], [hazard_triangle2[2]], [hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 270 < input.wind.azimuth <= 315
                coords = [vcat([hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle2[3]], [hazard_triangle2[1]], [hazard_triangle2[2]])]
            else
                coords = [vcat([hazard_triangle1]..., [hazard_triangle2[3]], [hazard_triangle2[1]])]
            end

        else
            if input.wind.azimuth <= 90
                coords = [vcat([hazard_triangle1]..., [hazard_triangle2[3]], [hazard_triangle2[1]])]
            elseif 90 < input.wind.azimuth <= 135
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle2[1]])]
            elseif 135 < input.wind.azimuth <= 180
                coords = [vcat([hazard_triangle1[1]], [hazard_triangle1[2]], [hazard_triangle2[2]], [hazard_triangle2[3]], [hazard_triangle1[3]])]
            elseif 180 < input.wind.azimuth <= 225
                coords = [vcat([hazard_triangle2]..., [hazard_triangle1[3]], [hazard_triangle1[1]])]
            elseif 225 < input.wind.azimuth <= 315
                coords = [vcat([hazard_triangle2[1]], [hazard_triangle2[2]], [hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle1[1]])]
            else
                coords = [vcat([hazard_triangle1[2]], [hazard_triangle1[3]], [hazard_triangle2[3]], [hazard_triangle2[1]], [hazard_triangle2[2]])]
            end
        end
        
        hazard_area = Polygon(coordinates = coords)
        prop2 = Dict("type" => "hazard", "shape" => "triangles")
        push!(feature, Feature(hazard_area, prop2))
    end
    FeatureCollection(feature)
end



"""
    proc(input, radius_release, radius_hazard, res = 360)

Calculate the release and hazard area according to the radius we want. Useful for simplified procedure and type A/B.
"""
function proc(input::Atp45Input, dist, radius_release, radius_hazard, res = 360)
    lon = input.locations[1][1]
    lat = input.locations[1][2]
    release_area = Polygon(coordinates = [circle_area(lon, lat, radius_release, res)])
    prop1 = Dict("type" => "release", "shape" => "circle")
    features = [Feature(release_area; properties = prop1)]
    if wind_speed(input.wind) <= 10
        hazard_area = Polygon(coordinates = [circle_area(lon, lat, radius_hazard, res)])
        prop2 = Dict("type" => "hazard", "shape" => "circle")
        push!(features, Feature(hazard_area; properties = prop2))
    else
        hazard_area = Polygon(coordinates = [hazard_area_triangle(lon, lat, input.wind, dist + 2*radius_release, radius_release)])
        prop2 = Dict("type" => "hazard", "shape" => "triangle")
        push!(features, Feature(hazard_area; properties = prop2))
    end
    FeatureCollection(features)
end



"""
Page 3-18 to 3-25 in NATO ATP-45: Warning  and Reporting and Hazard Prediction of CBRN Incidents (Operators Manual)

All Type B cases
"""
function typeB(input::Atp45Input, res = 360)
    if CONTAINERS[input.container][:type] == 1   # Page 3-19 and 3-20, Type B, Cases 1 and 2
        proc(input, 10000., 1000., 10000., res)
    elseif CONTAINERS[input.container][:type] == 2    # Page 3-21 to 3-23, Type B, Cases 3 and 4
        proc(input, 10000., 2000., 10000., res)
    elseif CONTAINERS[input.container][:type] == 3    # Page 3-24 and 3-25, Type B, Cases 5 and 6
        typeB_2(input, 1000., res)
    end
end




"""
Page 3-26 in NATO ATP-45: Warning  and Reporting and Hazard Prediction of CBRN Incidents (Operators Manual)

Type C/S
"""
function Unobserved(input::Atp45Input, radius, res = 360)
    lon = input.locations[1][1]
    lat = input.locations[1][2]
    hazard_area = Polygon(coordinates = [circle_area(lon, lat, radius, res)])
    prop = Dict("type" => "hazard", "shape" => "circle")
    feature = [Feature(hazard_area; properties = prop)]
    FeatureCollection(feature)
end
