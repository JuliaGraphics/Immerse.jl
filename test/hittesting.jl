import Immerse
using Gadfly, Gtk

x = linspace(0,4pi,101)
y = sin(x)
p = plot(x=x,y=y,Geom.line(tag=:line))
hfig = display(p)
Immerse.hit(hfig, :line, @guarded (mindist, i) -> Immerse.circle_center(hfig, :line, i))

Immerse.figure()
p2 = plot(x=x,y=y,Geom.point(tag=:line))
hfig2 = display(p2)
Immerse.hit(hfig2, :line, @guarded (mindist, i) -> Immerse.circle_center(hfig2, :line, i))
