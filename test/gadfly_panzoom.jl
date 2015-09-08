using Gadfly, Gtk.ShortNames, GtkUtilities, Colors, Graphics
import Immerse

y = rand(10^4)
# y = rand(10)
p = plot(x=1:length(y),y=y,Geom.line(tag=:line))

hfig = display(p)

panzoom(hfig, (1,length(y)), (minimum(y),maximum(y)))
idz = add_zoom_mouse(hfig)
idp = add_pan_mouse(hfig)
idzk = add_zoom_key(hfig)
idpk = add_pan_key(hfig)
