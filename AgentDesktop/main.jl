@use "github.com/jkroso/Prospects.jl" @def ["Enum" @Enum]

const lib = get(ENV, "AGENT_DESKTOP_LIB", "$(homedir())/Desktop/agent-desktop/target/debug/libagent_desktop_ffi.dylib")

@Enum Direction up down left right
@Enum Modifier cmd ctrl alt shift
@Enum MouseButton left right middle
@Enum MouseEventKind move down up click
@Enum ScreenshotKind screen window full_screen
@Enum ImageFormat png jpg
@Enum WindowOpKind resize move minimize maximize restore
@Enum ActionKind click double_click right_click triple_click set_value set_focus expand collapse select toggle check uncheck scroll scroll_to press_key key_down key_up type_text clear hover drag

to_c(e::Enum{UInt8}) = Int32(Integer(e) - 1)
from_c(T::Type{<:Enum{UInt8}}, v::Integer) = convert(T, v + 1)

@def struct Rect
  x::Float64 = 0.0
  y::Float64 = 0.0
  width::Float64 = 0.0
  height::Float64 = 0.0
end

@def struct Point
  x::Float64 = 0.0
  y::Float64 = 0.0
end

@def struct AppInfo
  name::String = ""
  pid::Int32 = Int32(0)
  bundle_id::String = ""
end

@def struct WindowInfo
  id::String = ""
  title::String = ""
  app::String = ""
  pid::Int32 = Int32(0)
  bounds::Union{Nothing,Rect} = nothing
  is_focused::Bool = false
end

@def struct SurfaceInfo
  kind::String = ""
  title::String = ""
  item_count::Int64 = Int64(0)
end

@def mutable struct Node
  ref_id::Union{Nothing,String} = nothing
  role::String = ""
  name::Union{Nothing,String} = nothing
  value::Union{Nothing,String} = nothing
  description::Union{Nothing,String} = nothing
  hint::Union{Nothing,String} = nothing
  states::Vector{String} = String[]
  bounds::Union{Nothing,Rect} = nothing
  children::Vector{Node} = Node[]
end

struct NativeHandle
  ptr::Ptr{Nothing}
end

@def struct ElementState
  role::String = ""
  states::Vector{String} = String[]
  value::Union{Nothing,String} = nothing
end

@def struct ActionResult
  action::String = ""
  ref_id::Union{Nothing,String} = nothing
  post_state::Union{Nothing,ElementState} = nothing
end

@def struct Image
  data::Vector{UInt8} = UInt8[]
  format::ImageFormat = ImageFormat.png
  width::UInt32 = UInt32(0)
  height::UInt32 = UInt32(0)
end

# Errors

struct AdError <: Exception
  code::Int32
  message::String
  suggestion::String
  detail::String
end

Base.showerror(io::IO, e::AdError) = begin
  print(io, "AdError($(e.code)): $(e.message)")
  isempty(e.suggestion) || print(io, "\n  suggestion: $(e.suggestion)")
  isempty(e.detail) || print(io, "\n  detail: $(e.detail)")
end

assert_ok(code::Int32) = begin
  code == 0 && return
  msg = ccall((:ad_last_error_message, lib), Ptr{UInt8}, ())
  sug = ccall((:ad_last_error_suggestion, lib), Ptr{UInt8}, ())
  det = ccall((:ad_last_error_platform_detail, lib), Ptr{UInt8}, ())
  throw(AdError(code,
    msg == C_NULL ? "Unknown error" : unsafe_string(msg),
    sug == C_NULL ? "" : unsafe_string(sug),
    det == C_NULL ? "" : unsafe_string(det)))
end

# C-layout structs

struct CAppInfo
  name::Ptr{UInt8}; pid::Int32; bundle_id::Ptr{UInt8}
end

struct CWindowInfo
  id::Ptr{UInt8}; title::Ptr{UInt8}; app_name::Ptr{UInt8}
  pid::Int32; bounds::Rect; has_bounds::Bool; is_focused::Bool
end

struct CSurfaceInfo
  kind::Ptr{UInt8}; title::Ptr{UInt8}; item_count::Int64
end

struct CNode
  ref_id::Ptr{UInt8}; role::Ptr{UInt8}; name::Ptr{UInt8}
  value::Ptr{UInt8}; description::Ptr{UInt8}; hint::Ptr{UInt8}
  states::Ptr{Ptr{UInt8}}; state_count::UInt32
  bounds::Rect; has_bounds::Bool
  parent_index::Int32; child_start::UInt32; child_count::UInt32
end

struct CNodeTree
  nodes::Ptr{CNode}; count::UInt32
end

struct CElementState
  role::Ptr{UInt8}; states::Ptr{Ptr{UInt8}}; state_count::UInt32; value::Ptr{UInt8}
end

struct CActionResult
  action::Ptr{UInt8}; ref_id::Ptr{UInt8}; post_state::Ptr{CElementState}
end

struct CImageBuffer
  data::Ptr{UInt8}; data_len::UInt64; format::Int32; width::UInt32; height::UInt32
end

struct CRefEntry
  pid::Int32; role::Ptr{UInt8}; name::Ptr{UInt8}
  bounds_hash::UInt64; has_bounds_hash::Bool
end

struct CScrollParams
  direction::Int32; amount::UInt32
end

struct CKeyCombo
  key::Ptr{UInt8}; modifiers::Ptr{Int32}; modifier_count::UInt32
end

struct CDragParams
  from::Point; to::Point; duration_ms::UInt64
end

struct CAction
  kind::Int32; text::Ptr{UInt8}
  scroll::CScrollParams; key::CKeyCombo; drag::CDragParams
end

struct CMouseEvent
  kind::Int32; point::Point; button::Int32; click_count::UInt32
end

struct CScreenshotTarget
  kind::Int32; screen_index::UInt64; pid::Int32
end

struct CTreeOptions
  max_depth::UInt8; include_bounds::Bool; interactive_only::Bool; compact::Bool
end

struct CWindowOp
  kind::Int32; width::Float64; height::Float64; x::Float64; y::Float64
end

const NULL_PTR = Ptr{UInt8}(0)
const EMPTY_SCROLL = CScrollParams(Int32(0), UInt32(0))
const EMPTY_KEY = CKeyCombo(NULL_PTR, Ptr{Int32}(0), UInt32(0))
const EMPTY_DRAG = CDragParams(Point(0, 0), Point(0, 0), UInt64(0))

# String helpers

maybe_string(p::Ptr{UInt8}) = p == C_NULL ? nothing : unsafe_string(p)
ensure_string(p::Ptr{UInt8}) = p == C_NULL ? "" : unsafe_string(p)

function string_vec(p::Ptr{Ptr{UInt8}}, n::Integer)
  n == 0 && return String[]
  [unsafe_string(unsafe_load(p, i)) for i in 1:n]
end

# C to Julia conversion

julia(c::CAppInfo) = AppInfo(ensure_string(c.name), c.pid, ensure_string(c.bundle_id))

julia(c::CWindowInfo) = WindowInfo(
  ensure_string(c.id), ensure_string(c.title), ensure_string(c.app_name),
  c.pid, c.has_bounds ? c.bounds : nothing, c.is_focused)

julia(c::CSurfaceInfo) = SurfaceInfo(ensure_string(c.kind), ensure_string(c.title), c.item_count)

function julia(p::Ptr{CElementState})
  p == C_NULL && return nothing
  c = unsafe_load(p)
  ElementState(ensure_string(c.role), string_vec(c.states, c.state_count), maybe_string(c.value))
end

julia(c::CActionResult) = ActionResult(ensure_string(c.action), maybe_string(c.ref_id), julia(c.post_state))

function julia(tree::CNodeTree)
  tree.count == 0 && return Node(role="empty")
  cnodes = unsafe_wrap(Array, tree.nodes, Int(tree.count))
  build_node(cnodes, 1)
end

function build_node(cnodes, idx::Int)
  cn = cnodes[idx]
  Node(
    ref_id=maybe_string(cn.ref_id), role=ensure_string(cn.role),
    name=maybe_string(cn.name), value=maybe_string(cn.value),
    description=maybe_string(cn.description), hint=maybe_string(cn.hint),
    states=string_vec(cn.states, cn.state_count),
    bounds=cn.has_bounds ? cn.bounds : nothing,
    children=[build_node(cnodes, Int(cn.child_start) + i) for i in 1:cn.child_count])
end

# Julia WindowInfo to C (for passing to C functions)

function with_c_window(f, w::WindowInfo)
  id = getfield(w, :id); title = getfield(w, :title); app = getfield(w, :app)
  bounds = getfield(w, :bounds)
  GC.@preserve id title app begin
    cw = CWindowInfo(pointer(id), pointer(title), pointer(app), getfield(w, :pid),
      something(bounds, Rect(0, 0, 0, 0)), !isnothing(bounds), getfield(w, :is_focused))
    f(Ref(cw))
  end
end

# Adapter

mutable struct Adapter
  ptr::Ptr{Nothing}
  function Adapter()
    ptr = ccall((:ad_adapter_create, lib), Ptr{Nothing}, ())
    ptr == C_NULL && error("Failed to create adapter")
    a = new(ptr)
    finalizer(a) do a
      a.ptr == C_NULL && return
      ccall((:ad_adapter_destroy, lib), Cvoid, (Ptr{Nothing},), a.ptr)
      a.ptr = C_NULL
    end
    a
  end
end

# API

check_permissions(a::Adapter) =
  assert_ok(ccall((:ad_check_permissions, lib), Int32, (Ptr{Nothing},), a.ptr))

function list_apps(a::Adapter)
  out = Ref(Ptr{CAppInfo}(0))
  count = Ref(UInt32(0))
  assert_ok(ccall((:ad_list_apps, lib), Int32,
    (Ptr{Nothing}, Ptr{Ptr{CAppInfo}}, Ptr{UInt32}), a.ptr, out, count))
  try [julia(unsafe_load(out[], i)) for i in 1:count[]]
  finally ccall((:ad_free_apps, lib), Cvoid, (Ptr{CAppInfo}, UInt32), out[], count[]) end
end

function launch(a::Adapter, id::String; timeout::Integer=5000)
  out = Ref(CWindowInfo(NULL_PTR, NULL_PTR, NULL_PTR, Int32(0), Rect(0,0,0,0), false, false))
  assert_ok(ccall((:ad_launch_app, lib), Int32,
    (Ptr{Nothing}, Cstring, UInt64, Ptr{CWindowInfo}), a.ptr, id, UInt64(timeout), out))
  try julia(out[])
  finally ccall((:ad_free_window, lib), Cvoid, (Ptr{CWindowInfo},), out) end
end

close_app(a::Adapter, id::String; force::Bool=false) =
  assert_ok(ccall((:ad_close_app, lib), Int32, (Ptr{Nothing}, Cstring, Bool), a.ptr, id, force))

function list_windows(a::Adapter; app::Union{Nothing,String}=nothing)
  out = Ref(Ptr{CWindowInfo}(0))
  count = Ref(UInt32(0))
  GC.@preserve app begin
    assert_ok(ccall((:ad_list_windows, lib), Int32,
      (Ptr{Nothing}, Ptr{UInt8}, Ptr{Ptr{CWindowInfo}}, Ptr{UInt32}),
      a.ptr, isnothing(app) ? NULL_PTR : pointer(app), out, count))
  end
  try [julia(unsafe_load(out[], i)) for i in 1:count[]]
  finally ccall((:ad_free_windows, lib), Cvoid, (Ptr{CWindowInfo}, UInt32), out[], count[]) end
end

focus(a::Adapter, w::WindowInfo) = with_c_window(w) do cw
  assert_ok(ccall((:ad_focus_window, lib), Int32, (Ptr{Nothing}, Ptr{CWindowInfo}), a.ptr, cw))
end

function window_op(a::Adapter, w::WindowInfo, kind; width=0.0, height=0.0, x=0.0, y=0.0)
  op = CWindowOp(to_c(kind), Float64(width), Float64(height), Float64(x), Float64(y))
  with_c_window(w) do cw
    assert_ok(ccall((:ad_window_op, lib), Int32,
      (Ptr{Nothing}, Ptr{CWindowInfo}, CWindowOp), a.ptr, cw, op))
  end
end

resize(a::Adapter, w::WindowInfo, width, height) = window_op(a, w, WindowOpKind.resize; width, height)
move_to(a::Adapter, w::WindowInfo, x, y) = window_op(a, w, WindowOpKind.move; x, y)
minimize(a::Adapter, w::WindowInfo) = window_op(a, w, WindowOpKind.minimize)
maximize(a::Adapter, w::WindowInfo) = window_op(a, w, WindowOpKind.maximize)
restore(a::Adapter, w::WindowInfo) = window_op(a, w, WindowOpKind.restore)

function get_tree(a::Adapter, w::WindowInfo;
    max_depth::Integer=10, include_bounds::Bool=false,
    interactive_only::Bool=false, compact::Bool=false)
  opts = Ref(CTreeOptions(UInt8(max_depth), include_bounds, interactive_only, compact))
  out = Ref(CNodeTree(Ptr{CNode}(0), UInt32(0)))
  with_c_window(w) do cw
    assert_ok(ccall((:ad_get_tree, lib), Int32,
      (Ptr{Nothing}, Ptr{CWindowInfo}, Ptr{CTreeOptions}, Ptr{CNodeTree}), a.ptr, cw, opts, out))
  end
  try julia(out[])
  finally ccall((:ad_free_tree, lib), Cvoid, (Ptr{CNodeTree},), out) end
end

function list_surfaces(a::Adapter, pid::Integer)
  out = Ref(Ptr{CSurfaceInfo}(0))
  count = Ref(UInt32(0))
  assert_ok(ccall((:ad_list_surfaces, lib), Int32,
    (Ptr{Nothing}, Int32, Ptr{Ptr{CSurfaceInfo}}, Ptr{UInt32}), a.ptr, Int32(pid), out, count))
  try [julia(unsafe_load(out[], i)) for i in 1:count[]]
  finally ccall((:ad_free_surfaces, lib), Cvoid, (Ptr{CSurfaceInfo}, UInt32), out[], count[]) end
end

# Element resolution

function resolve(a::Adapter; pid::Integer, role::String,
    name::Union{Nothing,String}=nothing, bounds_hash::Union{Nothing,Integer}=nothing)
  handle = Ref(NativeHandle(C_NULL))
  GC.@preserve role name begin
    entry = Ref(CRefEntry(Int32(pid), pointer(role),
      isnothing(name) ? NULL_PTR : pointer(name),
      isnothing(bounds_hash) ? UInt64(0) : UInt64(bounds_hash),
      !isnothing(bounds_hash)))
    assert_ok(ccall((:ad_resolve_element, lib), Int32,
      (Ptr{Nothing}, Ptr{CRefEntry}, Ptr{NativeHandle}), a.ptr, entry, handle))
  end
  handle[]
end

# Action execution (internal)

function run_action(a::Adapter, h::NativeHandle, action_ref)
  result = Ref(CActionResult(NULL_PTR, NULL_PTR, Ptr{CElementState}(0)))
  assert_ok(ccall((:ad_execute_action, lib), Int32,
    (Ptr{Nothing}, Ptr{NativeHandle}, Ptr{CAction}, Ptr{CActionResult}),
    a.ptr, Ref(h), action_ref, result))
  try julia(result[])
  finally ccall((:ad_free_action_result, lib), Cvoid, (Ptr{CActionResult},), result) end
end

make_action(kind) = Ref(CAction(to_c(kind), NULL_PTR, EMPTY_SCROLL, EMPTY_KEY, EMPTY_DRAG))

# Simple actions

click(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.click))
double_click(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.double_click))
right_click(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.right_click))
triple_click(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.triple_click))
set_focus(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.set_focus))
expand(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.expand))
collapse(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.collapse))
toggle(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.toggle))
check(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.check))
uncheck(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.uncheck))
scroll_to(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.scroll_to))
clear(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.clear))
hover(a::Adapter, h::NativeHandle) = run_action(a, h, make_action(ActionKind.hover))

# Text actions

function text_action(a::Adapter, h::NativeHandle, kind, text::String)
  GC.@preserve text begin
    run_action(a, h, Ref(CAction(to_c(kind), pointer(text), EMPTY_SCROLL, EMPTY_KEY, EMPTY_DRAG)))
  end
end

set_value(a::Adapter, h::NativeHandle, text::String) = text_action(a, h, ActionKind.set_value, text)
select(a::Adapter, h::NativeHandle, text::String) = text_action(a, h, ActionKind.select, text)
type_text(a::Adapter, h::NativeHandle, text::String) = text_action(a, h, ActionKind.type_text, text)

# Scroll action

function scroll(a::Adapter, h::NativeHandle, direction::Direction, amount::Integer=3)
  action = Ref(CAction(to_c(ActionKind.scroll), NULL_PTR,
    CScrollParams(to_c(direction), UInt32(amount)), EMPTY_KEY, EMPTY_DRAG))
  run_action(a, h, action)
end

# Key actions

function key_action(a::Adapter, h::NativeHandle, kind, key::String; modifiers::Vector=Modifier[])
  mod_ints = Int32[to_c(m) for m in modifiers]
  GC.@preserve key mod_ints begin
    combo = CKeyCombo(pointer(key),
      isempty(mod_ints) ? Ptr{Int32}(0) : pointer(mod_ints),
      UInt32(length(mod_ints)))
    run_action(a, h, Ref(CAction(to_c(kind), NULL_PTR, EMPTY_SCROLL, combo, EMPTY_DRAG)))
  end
end

press_key(a::Adapter, h::NativeHandle, key::String; kw...) = key_action(a, h, ActionKind.press_key, key; kw...)
key_down(a::Adapter, h::NativeHandle, key::String; kw...) = key_action(a, h, ActionKind.key_down, key; kw...)
key_up(a::Adapter, h::NativeHandle, key::String; kw...) = key_action(a, h, ActionKind.key_up, key; kw...)

# Screenshots

function screenshot(a::Adapter, target::CScreenshotTarget)
  out = Ref(CImageBuffer(Ptr{UInt8}(0), UInt64(0), Int32(0), UInt32(0), UInt32(0)))
  assert_ok(ccall((:ad_screenshot, lib), Int32,
    (Ptr{Nothing}, Ptr{CScreenshotTarget}, Ptr{CImageBuffer}), a.ptr, Ref(target), out))
  img = out[]
  try
    Image(unsafe_wrap(Array, img.data, Int(img.data_len)) |> copy,
      from_c(ImageFormat, img.format), img.width, img.height)
  finally ccall((:ad_free_image, lib), Cvoid, (Ptr{CImageBuffer},), out) end
end

screenshot(a::Adapter) = screenshot(a, CScreenshotTarget(to_c(ScreenshotKind.full_screen), UInt64(0), Int32(0)))
screenshot(a::Adapter, screen_index::Integer) = screenshot(a, CScreenshotTarget(to_c(ScreenshotKind.screen), UInt64(screen_index), Int32(0)))
screenshot(a::Adapter, w::WindowInfo) = screenshot(a, CScreenshotTarget(to_c(ScreenshotKind.window), UInt64(0), w.pid))

# Clipboard

function get_clipboard(a::Adapter)
  out = Ref(Ptr{UInt8}(0))
  assert_ok(ccall((:ad_get_clipboard, lib), Int32, (Ptr{Nothing}, Ptr{Ptr{UInt8}}), a.ptr, out))
  try out[] == C_NULL ? "" : unsafe_string(out[])
  finally ccall((:ad_free_string, lib), Cvoid, (Ptr{UInt8},), out[]) end
end

set_clipboard(a::Adapter, text::String) =
  assert_ok(ccall((:ad_set_clipboard, lib), Int32, (Ptr{Nothing}, Cstring), a.ptr, text))

clear_clipboard(a::Adapter) =
  assert_ok(ccall((:ad_clear_clipboard, lib), Int32, (Ptr{Nothing},), a.ptr))

# Mouse

function mouse(a::Adapter, kind::MouseEventKind, x::Real, y::Real;
    button::MouseButton=MouseButton.left, clicks::Integer=1)
  event = Ref(CMouseEvent(to_c(kind), Point(Float64(x), Float64(y)), to_c(button), UInt32(clicks)))
  assert_ok(ccall((:ad_mouse_event, lib), Int32, (Ptr{Nothing}, Ptr{CMouseEvent}), a.ptr, event))
end

function drag(a::Adapter, from::Point, to::Point; duration::Integer=0)
  params = Ref(CDragParams(from, to, UInt64(duration)))
  assert_ok(ccall((:ad_drag, lib), Int32, (Ptr{Nothing}, Ptr{CDragParams}), a.ptr, params))
end
