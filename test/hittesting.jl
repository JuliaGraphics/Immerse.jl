using Immerse, Gtk

x = range(0,stop=4pi,length=101)
y = sin.(x)

figure()
p = plot(x=x,y=y,Geom.point(tag=:dots),Geom.line(tag=:line))
hfig = display(p)
hit((hfig,:dots), @guarded (figtag, i, event, dist) -> if dist < 1 Immerse.circle_center(figtag, i) end)
hit((hfig,:line), @guarded (figtag, index, event, dist) -> begin
    if dist < 2
        println("You clicked on line ", index[1], " in segment ", index[2], " at $(round(Int,100*index[3]))% along the segment")
    end
end)
