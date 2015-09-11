using Immerse
using Gadfly, Gtk

x = linspace(0,4pi,101)
y = sin(x)
figure()
p = plot(x=x,y=y,Geom.line(tag=:line))
hfig = display(p)
hit(hfig, :line, @guarded (mindist, i) -> Immerse.circle_center(hfig, :line, i))

figure()
p2 = plot(x=x,y=y,Geom.point(tag=:line))
hfig2 = display(p2)
hit(hfig2, :line, @guarded (mindist, i) -> Immerse.circle_center(hfig2, :line, i))
