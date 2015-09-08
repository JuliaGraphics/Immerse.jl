using Gadfly, Gtk.ShortNames, GtkUtilities, Colors, Graphics
import Immerse

y = rand(10^4)
# y = rand(10)
p = plot(x=1:length(y),y=y,Geom.line(tag=:line))

hfig = display(p)
