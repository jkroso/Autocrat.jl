@use "." Error ms BUTTONS check Direction position displays windows
@use Dates Millisecond Second Minute
@use Test...

@testset "Autocrat" begin
  @testset "BUTTONS" begin
    @test BUTTONS[:left] == 0
    @test BUTTONS[:right] == 1
    @test BUTTONS[:middle] == 2
    @test_throws KeyError BUTTONS[:invalid]
  end

  @testset "ms" begin
    @test ms(nothing) == -1
    @test ms(Millisecond(20)) == 20
    @test ms(Millisecond(0)) == 0
    @test ms(Second(1)) == 1000
    @test ms(Minute(1)) == 60000
  end

  @testset "Direction" begin
    @test Direction.up isa Direction
    @test Direction.down isa Direction
    @test Direction.left isa Direction
    @test Direction.right isa Direction
    @test nameof(Direction.up) == :up
  end

  @testset "Error" begin
    err = Error("test error")
    @test err.msg == "test error"
    buf = IOBuffer()
    showerror(buf, err)
    @test String(take!(buf)) == "AutocratError: test error"
  end

  @testset "position" begin
    pos = position()
    @test pos isa Tuple{Float64,Float64}
    @test length(pos) == 2
  end

  @testset "displays" begin
    ds = displays()
    @test ds isa AbstractVector
    @test length(ds) > 0
    d = first(ds)
    @test haskey(d, "index")
    @test haskey(d, "name")
    @test haskey(d, "width")
    @test haskey(d, "height")
    @test haskey(d, "isPrimary")
  end

  @testset "windows" begin
    ws = windows()
    @test ws isa AbstractVector
    @test length(ws) > 0
    w = first(ws)
    @test haskey(w, "ownerName")
    @test haskey(w, "title")
    @test haskey(w, "width")
    @test haskey(w, "height")
    @test haskey(w, "x")
    @test haskey(w, "y")
  end
end
