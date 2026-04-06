@use "." Adapter adapter AdError Direction MouseButton WindowInfo check_permissions list_windows screenshot windows
@use Test...

@testset "Autocrat" begin
  @testset "Direction" begin
    @test Direction.up isa Direction
    @test Direction.down isa Direction
    @test Direction.left isa Direction
    @test Direction.right isa Direction
    @test nameof(Direction.up) == :up
  end

  @testset "MouseButton" begin
    @test MouseButton.left isa MouseButton
    @test MouseButton.right isa MouseButton
    @test MouseButton.middle isa MouseButton
  end

  @testset "adapter" begin
    @test adapter() isa Adapter
  end

  @testset "windows" begin
    ws = windows()
    @test ws isa Vector{WindowInfo}
    @test length(ws) > 0
    w = first(ws)
    @test w.app isa String
    @test w.title isa String
    @test w.pid isa Int32
  end

  @testset "screenshot" begin
    img = screenshot()
    @test img.width > 0
    @test img.height > 0
    @test length(img.data) > 0
  end
end
