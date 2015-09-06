import Immerse
using Gadfly

x = linspace(0,4pi,101)
y = sin(x)
p = plot(x=x,y=y,Geom.line(tag=:line))
hfig = display(p)
hline = Immerse.handle(hfig, :line)

Immerse.hit(hfig, hline, (mindist, itemindex, entryindex) -> Immerse.circle_center(hfig.canvas, hline, itemindex, entryindex))
