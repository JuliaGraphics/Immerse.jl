using Immerse, Gtk

x = linspace(0,4pi,101)
y = sin(x)

figure()
p = plot(x=x,y=y,Geom.point(tag=:dots),Geom.line(tag=:line))
hfig = display(p)
let hfig = hfig
    hit(hfig, :dots, @guarded (tag, i, xy, dist) -> if dist < 1 Immerse.circle_center(hfig, :dots, i) end)
    hit(hfig, :line, @guarded (tag, index, xy, dist) -> begin
        if dist < 2
            println("You clicked on line ", index[1], " in segment ", index[2], " at $(round(Int,100*index[3]))% along the segment")
        end
    end)
end
