using Immerse, Colors

hfig = figure()
x = linspace(0,4pi,101)
display(plot(x=x, y=sin(x), Geom.line(tag=:line)))
val = setproperty!((hfig,:line), rand(1:5), :linewidth)
@test getproperty((hfig,:line), :linewidth) == [Compose.Measure(val)]
val = setproperty!((hfig,:line), RGB(rand(),rand(),rand()), :stroke)
@test getproperty((hfig,:line), :stroke) == [coloralpha(val)]
setproperty!((hfig,:line), false, :visible)
@test getproperty((hfig,:line), :visible) == [false]
setproperty!((hfig,:line), true, :visible)
@test getproperty((hfig,:line), :visible) == [true]
