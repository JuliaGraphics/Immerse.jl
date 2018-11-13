using Immerse
using Test

p = plot(x=rand(5), y=rand(5), Geom.line)
fig = display(p)
fignew = display(plot(x=rand(5), y=rand(5), Geom.point))
@test fig == fignew
@test gcf() == fig
figure()
fignew = display(plot(x=rand(5), y=rand(5), Geom.point))
@test fig != fignew
@test gcf() != fig
@test gcf() == fignew
figure(fig)
@test gcf() == fig
display(plot(x=rand(5), y=rand(5), Geom.line))
@test isa(Figure(fig), Figure)
closefig(fignew)

closeall()

# Issue #56
let hfig = figure()
    Immerse.panzoom_cb(Figure(hfig))
    Immerse.save_as(Figure(hfig))
    closefig(hfig)
end
