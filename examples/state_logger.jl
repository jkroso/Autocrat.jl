@use ".." spy spy_stop mouse keyboard

restore() = (spy_stop(); print("\e[?25h"); ccall(:system, Cint, (Cstring,), "stty echo sane"))
atexit(restore)

ccall(:system, Cint, (Cstring,), "stty -echo")
print("\e[?25l\e[2J") # hide cursor, clear screen

spy() do t, e
  print("\e[H") # cursor to top-left
  println("Mouse:    ($(mouse.x), $(mouse.y))  buttons: $(mouse.buttons)         ")
  println("Keyboard: $(keyboard.state)                                           ")
end

try wait() catch end
restore()
