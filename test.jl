@use "." AD adapter windows screenshot
@use Test...

@testset "Autocrat" begin
  @testset "Direction" begin
    @test AD.Direction.up isa AD.Direction
    @test AD.Direction.down isa AD.Direction
    @test AD.Direction.left isa AD.Direction
    @test AD.Direction.right isa AD.Direction
    @test nameof(AD.Direction.up) == :up
  end

  @testset "MouseButton" begin
    @test AD.MouseButton.left isa AD.MouseButton
    @test AD.MouseButton.right isa AD.MouseButton
    @test AD.MouseButton.middle isa AD.MouseButton
  end

  @testset "adapter" begin
    @test adapter() isa AD.Adapter
  end

  @testset "windows" begin
    ws = windows()
    @test ws isa Vector{AD.WindowInfo}
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
