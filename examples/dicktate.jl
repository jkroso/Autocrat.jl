@use ".." move hold release click windows MouseButton

const canvas_html = """
<!DOCTYPE html>
<html>
<head><title>Autocrat Canvas</title></head>
<body style="margin:0;overflow:hidden;cursor:crosshair;background:#fff">
<canvas id="c"></canvas>
<script>
const c=document.getElementById('c');
c.width=innerWidth;c.height=innerHeight;
const x=c.getContext('2d');
x.lineWidth=3;x.lineCap='round';x.lineJoin='round';
let d=false,lx,ly;
c.onmousedown=e=>{d=true;lx=e.x;ly=e.y};
c.onmousemove=e=>{if(d){x.beginPath();x.moveTo(lx,ly);x.lineTo(e.x,e.y);x.stroke();lx=e.x;ly=e.y}};
c.onmouseup=()=>d=false;
</script>
</body>
</html>
"""

function open_canvas()
  path = tempname() * ".html"
  write(path, canvas_html)
  run(`open $path`)
  sleep(3)
end

function stroke(points)
  move(points[1]...)
  sleep(0.05)
  hold(MouseButton.left)
  for (x, y) in points[2:end]
    move(x, y)
    sleep(0.01)
  end
  release(MouseButton.left)
  sleep(0.05)
end

circle(cx, cy, r; n=40) =
  [(cx + r*cos(t), cy + r*sin(t)) for t in range(0, 2π, length=n+1)]

function draw(cx=600, cy=500; s=1.0)
  hw = 20s

  # balls
  stroke(circle(cx - 25s, cy + 80s, 22s))
  stroke(circle(cx + 25s, cy + 80s, 22s))

  # shaft + head
  bottom = cy + 55s
  top = cy - 60s
  left = [(cx - hw, y) for y in range(bottom, top, length=20)]
  head = [(cx + 24s*cos(t), top - 24s*sin(t)) for t in range(π, 0, length=25)]
  right = [(cx + hw, y) for y in range(top, bottom, length=20)]
  stroke(vcat(left, head, right))
end

function find_canvas()
  for w in windows()
    occursin("Autocrat Canvas", get(w, "title", "")) && return w
  end
  error("No canvas window found")
end

open_canvas()
w = find_canvas()
cx = w["x"] + w["width"] / 2
cy = w["y"] + w["height"] / 2
click(cx, cy)
sleep(0.5)
draw(cx, cy)
println("Done.")
