import Immerse
using Gadfly

x = linspace(0,4pi,101)
y = sin(x)
p = plot(x=x,y=y,Geom.line(tag=:line))
hfig = display(p)
Immerse.hit(hfig, :line, (mindist, itemindex, entryindex) -> Immerse.circle_center(hfig, :line, itemindex, entryindex))
