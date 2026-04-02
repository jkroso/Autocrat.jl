# Autocrat.jl

I always though computers couldn't control themselves. Turns out they lack only self control.

![this autocrat is a dicktator](./dictator.gif)

This is mostly a thin wrapper around [usecomputer](https://github.com/remorses/usecomputer) and [libuiohook](https://github.com/kwhat/libuiohook). It provides `mouse` and `keyboard` objects that you can read and write to, along with a few helpful functions

## API

### Mouse

```julia
mouse.position = (200, 300) # move to (x=200, y=300) 
mouse.position # => (200, 300)
mouse.left = true # hold down the left mouse button
mouse.left = false # release the left mouse button
# move to a point while holding a mouse button down
drag((900, 300); cp=(nothing), button=MouseButton.left) # cp is control point. It will curve towards the point while traveling to `to`
click(100, 200; button=MouseButton.left, count=1)
```

### Keyboard

```julia
keyboard.h = true # h key down
keyboard.h = false # h key up
type("ello world"; delay=nothing) # for convenience we can finish typing with the type method
press("enter"; count=1, delay=nothing) 
press(Keys.cmd|Keys.c) # press key combos
```

Delays accept `Dates.Period` values like `Millisecond(20)` or `Second(1)`.

### Scrolling

```julia
scroll(Direction.up; amount=3, at=nothing)
```

Directions: `up`, `down`, `left`, `right`.

### Screenshots & Display Info

```julia
screenshot(; path=nothing, display=nothing, window=nothing)
displays() # list all displays
windows()  # list all windows
```

### Input Events

```julia
spy(handle_event)
```

`Keys` is a `@BitSet` representing all keyboard keys. Test combos with `key_state == Keys.cmd|Keys.c`.

## Examples

See the `examples/` directory:

- **event_logger.jl** -- logs all input events to stdout
- **state_logger.jl** -- live display of mouse position, buttons, and keyboard state
- **dicktate.jl** -- opens an HTML canvas and draws on it programmatically
