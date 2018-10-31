using Immerse, Colors

hfig = figure()
x = range(0, stop=4pi, length=101)
display(plot(x=x, y=sin.(x), Geom.line(tag=:line)))

val = Immerse.setproperty!((hfig,:line), rand(1:5), :linewidth)
@test Immerse.getproperty((hfig,:line), :linewidth) == [val*mm]
val = Immerse.setproperty!((hfig,:line), RGB(rand(),rand(),rand()), :stroke)
@test Immerse.getproperty((hfig,:line), :stroke) == [coloralpha(val)]
Immerse.setproperty!((hfig,:line), false, :visible)
@test Immerse.getproperty((hfig,:line), :visible) == [false]
Immerse.setproperty!((hfig,:line), true, :visible)
@test Immerse.getproperty((hfig,:line), :visible) == [true]
