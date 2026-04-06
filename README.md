# Autocrat.jl

I always though computers couldn't control themselves. Turns out they lack only self control.

![this autocrat is a dicktator](./dictator.gif)

A wrapper around [AgentDesktop](https://github.com/anthropics/agent-desktop) providing `mouse` and `keyboard` objects you can read and write to, along with accessibility tree access, window management, and input event monitoring.

## API

### Mouse

```julia
mouse.position = (200, 300) # move to (x=200, y=300)
mouse.position # => (200, 300)
mouse.left = true # hold down the left mouse button
mouse.left = false # release the left mouse button
click(100, 200; button=MouseButton.left, count=1)
drag((900, 300); duration=0)
```

### Keyboard

```julia
keyboard.h = true  # h key down
keyboard.h = false # h key up
keyboard.cmd = true  # hold command
keyboard.c = true    # press c (with cmd held)
keyboard.c = false
keyboard.cmd = false
```

`Keys` is a `@BitSet` representing all keyboard keys. Test combos with `keyboard.state == Keys.cmd|Keys.c`.

### Screenshots

```julia
screenshot()              # full screen, returns Image
screenshot(w)             # specific window
screenshot(screen_index)  # specific display
```

### Windows & Apps

```julia
windows()                            # list all windows
list_apps()                          # list running apps
focus(w)                             # focus a window
resize(w, 1200, 800)                 # resize
move_to(w, 100, 100)                 # reposition
launch("com.apple.Safari")           # launch by bundle id
```

### Accessibility Tree

```julia
tree = get_tree(w, max_depth=3, interactive_only=true, include_bounds=true)
handle = resolve(pid=w.pid, role="button", name="OK")
click(handle)
type_text(handle, "hello")
press_key(handle, "c", modifiers=[Modifier.cmd])
scroll(handle, Direction.down, 5)
```

### Clipboard

```julia
set_clipboard("hello")
get_clipboard()
clear_clipboard()
```

### Input Events

```julia
spy() do type, event
  println(type, " ", event)
end
spy_stop()
```

## Examples

See the `examples/` directory:

- **event_logger.jl** -- logs all input events to stdout
- **state_logger.jl** -- live display of mouse position, buttons, and keyboard state
- **dicktate.jl** -- opens an HTML canvas and draws on it programmatically
