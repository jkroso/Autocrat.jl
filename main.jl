@use "github.com/jkroso/Prospects.jl" @def @property Field ["BitSet" @BitSet] ["Enum" @Enum]
@use "github.com/jkroso/Units.jl/Typography" px

# AgentDesktop replaces usecomputer_jll
@use "../../AgentDesktop.jl" => AD

for name in [:Adapter, :AdError, :Direction, :Modifier, :MouseButton, :MouseEventKind,
             :ScreenshotKind, :ImageFormat, :WindowOpKind, :ActionKind,
             :Rect, :Point, :AppInfo, :WindowInfo, :SurfaceInfo, :Node, :NativeHandle,
             :ElementState, :ActionResult, :Image,
             :check_permissions, :list_apps, :launch, :close_app, :list_windows,
             :focus, :resize, :move_to, :minimize, :maximize, :restore,
             :get_tree, :list_surfaces, :resolve,
             :double_click, :right_click, :triple_click, :set_focus, :expand, :collapse, :toggle,
             :check, :uncheck, :scroll_to, :clear, :hover,
             :set_value, :select, :type_text, :scroll,
             :press_key, :key_down, :key_up,
             :get_clipboard, :set_clipboard, :clear_clipboard]
  @eval const $name = AD.$name
end

const _adapter = Ref{Adapter}()
function adapter()
  isassigned(_adapter) && return _adapter[]
  a = Adapter()
  check_permissions(a)
  _adapter[] = a
end

# Click: element-based + coordinate-based
click(a::Adapter, h::NativeHandle) = AD.click(a, h)
click(x::Real, y::Real; button::MouseButton=MouseButton.left, count::Integer=1) = begin
  setfield!(mouse, :x, round(Int, x))
  setfield!(mouse, :y, round(Int, y))
  AD.mouse(adapter(), MouseEventKind.click, x, y; button, clicks=count)
end

# Drag: adapter-based + coordinate-based
drag(a::Adapter, from::Point, to::Point; duration::Integer=0) = AD.drag(a, from, to; duration)
drag((to_x, to_y)::Tuple{Real,Real}; duration::Integer=0) = begin
  from = Point(Float64(mouse.x), Float64(mouse.y))
  setfield!(mouse, :x, round(Int, to_x))
  setfield!(mouse, :y, round(Int, to_y))
  AD.drag(adapter(), from, Point(Float64(to_x), Float64(to_y)); duration)
end

# Screenshot: adapter-based + convenience shortcuts
screenshot(a::Adapter) = AD.screenshot(a)
screenshot(a::Adapter, screen_index::Integer) = AD.screenshot(a, screen_index)
screenshot(a::Adapter, w::WindowInfo) = AD.screenshot(a, w)
screenshot() = AD.screenshot(adapter())
screenshot(w::WindowInfo) = AD.screenshot(adapter(), w)
screenshot(screen_index::Integer) = AD.screenshot(adapter(), screen_index)

# Coordinate-based mouse convenience
move(x::Real, y::Real) = begin
  setfield!(mouse, :x, round(Int, x))
  setfield!(mouse, :y, round(Int, y))
  AD.mouse(adapter(), MouseEventKind.move, x, y)
end

hold(button::MouseButton=MouseButton.left) =
  AD.mouse(adapter(), MouseEventKind.down, mouse.x, mouse.y; button)

release(button::MouseButton=MouseButton.left) =
  AD.mouse(adapter(), MouseEventKind.up, mouse.x, mouse.y; button)

# No-adapter convenience
windows() = list_windows(adapter())

"""
A very efficient way of representing every possible keyboard button combination. To test for cmd+c you write `key_state == Keys.cmd|Keys.c`
"""
@BitSet Keys """
  tilde minus equal left_bracket right_bracket semicolon apostrophe comma period slash backslash times plus
  a:z 0:9 num(0:9) f(1:25) tab capslock enter shft cmd opt ctrl escape delete backspace space fn home pageup
  pagedown _end clear eject insert left right up down
"""

@BitSet MouseState left middle right

int(n::px) = round(Int, n.value)
int(x::Integer) = x
int(x::Real) = round(Int, x)

@def mutable struct Mouse
  x::Int
  y::Int
  buttons::MouseState
end

@property Mouse.position = (self.x, self.y)

@def mutable struct Keyboard
  state::Keys
end

Base.setproperty!(m::Mouse, ::Field{:position}, (x, y)) = begin
  m.x = int(x)
  m.y = int(y)
  move(m.x, m.y)
end

Base.setproperty!(::Mouse, ::Field{f}, down::Bool) where f = begin
  button = getproperty(MouseButton, f)
  if down
    hold(button)
  else
    release(button)
  end
  down
end

@Enum EventType mouse_move mouse_down mouse_up scroll key_down key_up flags_changed

struct Event
  type::Cint
  timestamp::Cdouble
  x::Cdouble
  y::Cdouble
  button::Cint
  click_count::Cint
  scroll_dx::Cdouble
  scroll_dy::Cdouble
  keycode::Cint
  modifiers::Cuint
end

EventType(e::Event) = EventType(e.type + 1)

# macOS virtual keycode -> Keys mapping
const KEYMAP = Dict{Cint,Keys}(
  # letters
  0=>Keys.a, 11=>Keys.b, 8=>Keys.c, 2=>Keys.d, 14=>Keys.e, 3=>Keys.f, 5=>Keys.g,
  4=>Keys.h, 34=>Keys.i, 38=>Keys.j, 40=>Keys.k, 37=>Keys.l, 46=>Keys.m, 45=>Keys.n,
  31=>Keys.o, 35=>Keys.p, 12=>Keys.q, 15=>Keys.r, 1=>Keys.s, 17=>Keys.t, 32=>Keys.u,
  9=>Keys.v, 13=>Keys.w, 7=>Keys.x, 16=>Keys.y, 6=>Keys.z,
  # numbers
  29=>getproperty(Keys, Symbol("0")), 18=>getproperty(Keys, Symbol("1")),
  19=>getproperty(Keys, Symbol("2")), 20=>getproperty(Keys, Symbol("3")),
  21=>getproperty(Keys, Symbol("4")), 23=>getproperty(Keys, Symbol("5")),
  22=>getproperty(Keys, Symbol("6")), 26=>getproperty(Keys, Symbol("7")),
  28=>getproperty(Keys, Symbol("8")), 25=>getproperty(Keys, Symbol("9")),
  # punctuation
  50=>Keys.tilde, 27=>Keys.minus, 24=>Keys.equal, 33=>Keys.left_bracket,
  30=>Keys.right_bracket, 41=>Keys.semicolon, 39=>Keys.apostrophe, 43=>Keys.comma,
  47=>Keys.period, 44=>Keys.slash, 42=>Keys.backslash,
  # special
  48=>Keys.tab, 57=>Keys.capslock, 36=>Keys.enter, 56=>Keys.shft, 60=>Keys.shft,
  55=>Keys.cmd, 54=>Keys.cmd, 58=>Keys.opt, 61=>Keys.opt, 59=>Keys.ctrl, 62=>Keys.ctrl,
  53=>Keys.escape, 51=>Keys.backspace, 117=>Keys.delete, 49=>Keys.space, 63=>Keys.fn,
  # navigation
  115=>Keys.home, 116=>Keys.pageup, 121=>Keys.pagedown, 119=>Keys._end,
  71=>Keys.clear, 123=>Keys.left, 124=>Keys.right, 125=>Keys.down, 126=>Keys.up,
  # function keys
  122=>Keys.f1, 120=>Keys.f2, 99=>Keys.f3, 118=>Keys.f4, 96=>Keys.f5, 97=>Keys.f6,
  98=>Keys.f7, 100=>Keys.f8, 101=>Keys.f9, 109=>Keys.f10, 103=>Keys.f11, 111=>Keys.f12,
  105=>Keys.f13, 107=>Keys.f14, 113=>Keys.f15, 106=>Keys.f16, 64=>Keys.f17, 79=>Keys.f18,
  80=>Keys.f19, 90=>Keys.f20,
  # numpad
  82=>Keys.num0, 83=>Keys.num1, 84=>Keys.num2, 85=>Keys.num3, 86=>Keys.num4,
  87=>Keys.num5, 88=>Keys.num6, 89=>Keys.num7, 91=>Keys.num8, 92=>Keys.num9,
)

# macOS modifier keycode -> CGEventFlags bit
const MODFLAGS = Dict{Cint,Cuint}(
  56=>0x20000, 60=>0x20000,   # shift
  59=>0x40000, 62=>0x40000,   # control
  58=>0x80000, 61=>0x80000,   # option
  55=>0x100000, 54=>0x100000, # command
  57=>0x10000,                # caps lock
  63=>0x800000,               # fn
)

const BUTTONMAP = (MouseState.left, MouseState.right, MouseState.middle)

const _spy_running = Ref(false)

function _update_state(t::EventType, e::Event)
  if t == EventType.mouse_move
    setfield!(mouse, :x, round(Int, e.x))
    setfield!(mouse, :y, round(Int, e.y))
  elseif t == EventType.mouse_down
    btn = BUTTONMAP[clamp(e.button + 1, 1, 3)]
    setfield!(mouse, :buttons, getfield(mouse, :buttons) | btn)
  elseif t == EventType.mouse_up
    btn = BUTTONMAP[clamp(e.button + 1, 1, 3)]
    setfield!(mouse, :buttons, setdiff(getfield(mouse, :buttons), btn))
  elseif t == EventType.key_down
    key = get(KEYMAP, e.keycode, nothing)
    key !== nothing && setfield!(keyboard, :state, getfield(keyboard, :state) | key)
  elseif t == EventType.key_up
    key = get(KEYMAP, e.keycode, nothing)
    key !== nothing && setfield!(keyboard, :state, setdiff(getfield(keyboard, :state), key))
  elseif t == EventType.flags_changed
    key = get(KEYMAP, e.keycode, nothing)
    flag = get(MODFLAGS, e.keycode, nothing)
    if key !== nothing && flag !== nothing
      if e.modifiers & flag != 0
        setfield!(keyboard, :state, getfield(keyboard, :state) | key)
      else
        setfield!(keyboard, :state, setdiff(getfield(keyboard, :state), key))
      end
    end
  end
end

const eventlib = let
  src = joinpath(@__DIR__, "events.c")
  lib = joinpath(@__DIR__, ".build", "libevents.dylib")
  if !isfile(lib) || mtime(src) > mtime(lib)
    mkpath(dirname(lib))
    run(`cc -shared -O2 -framework CoreGraphics -framework ApplicationServices -framework CoreFoundation -o $lib $src`)
  end
  lib
end

function spy(cb)
  _spy_running[] = true
  rc = @ccall eventlib.ac_start()::Cint
  if rc != 0
    _spy_running[] = false
    throw(AdError(Int32(rc), rc == -2 ? "Accessibility permission required" : "failed to start event tap (rc=$rc)", "", ""))
  end
  ring_ptr = @ccall eventlib.ac_ring()::Ptr{Event}
  count_ptr = @ccall eventlib.ac_count()::Ptr{Int64}
  @async begin
    read_pos = Int64(0)
    while _spy_running[]
      n = unsafe_load(count_ptr)
      while read_pos < n
        read_pos += 1
        e = unsafe_load(ring_ptr, mod1(read_pos, 1024))
        t = EventType(e)
        _update_state(t, e)
        cb(t, e)
      end
      sleep(0.001)
    end
  end
end

function spy_stop()
  _spy_running[] = false
  @ccall eventlib.ac_stop()::Cvoid
end

"The Mouse"
const mouse = Mouse(0, 0, MouseState(0))
"The Keyboard"
const keyboard = Keyboard(Keys(0))
