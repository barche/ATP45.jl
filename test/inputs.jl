using Test
using ATP45
import ATP45: Simplified
import ATP45: AbstractWind, WindDirection, ReleaseLocation, AbstractReleaseLocation
import ATP45: AbstractStability, Unstable, Stable
import ATP45: get_input

@testset "Inputs" begin
    simple = Simplified()
    wind = WindDirection(11., 45)
    release = ReleaseLocation([4., 50.])
    stable = Stable()

    inputs = (wind, release, stable)
    @test get_input(inputs, AbstractWind) == wind
    @test get_input(inputs, AbstractReleaseLocation) == release
    @test get_input(inputs, AbstractStability) == stable
    @test_throws ErrorException get_input([wind], AbstractReleaseLocation)
end
