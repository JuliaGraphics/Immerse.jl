import Immerse
using Gadfly

x = linspace(0,4pi,101)
y = sin(x)
p = plot(x=x,y=y,Geom.line(tag=:line))
hfig = display(p)
hline = hfig[:line]

Immerse.hit(hline, (mindist, itemindex, entryindex) -> Immerse.circle_center(hline, itemindex, entryindex))
