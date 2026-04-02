@use ".." spy spy_stop EventType Event

log(t, e::Event) = begin
  n = nameof(t)
  if t == EventType.mouse_move
    println("[$n] at ($(e.x), $(e.y))")
  elseif t == EventType.mouse_down || t == EventType.mouse_up
    println("[$n] button=$(e.button) clicks=$(e.click_count) at ($(e.x), $(e.y))")
  elseif t == EventType.scroll
    println("[$n] dx=$(e.scroll_dx) dy=$(e.scroll_dy) at ($(e.x), $(e.y))")
  elseif t == EventType.key_down || t == EventType.key_up
    println("[$n] keycode=$(e.keycode) modifiers=$(e.modifiers)")
  elseif t == EventType.flags_changed
    println("[$n] modifiers=$(e.modifiers)")
  end
end

println("Logging input events. Press Ctrl-C to stop.\n")

wait(spy(log))
spy_stop()
