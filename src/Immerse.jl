module Immerse

using GtkUtilities, Colors, Reexport, Compat, REPL, Graphics
@reexport using Gadfly
import Gtk   # because both Gadfly and Gtk define draw
import Measures
using Compose, Cairo

export
    Figure,
    closefig,
    closeall,
    figure,
    gcf,
    scf,
    getproperty,
    setproperty!,
    hit,
    lasso_initialize

# Stuff for Gadfly/Compose
include("compose.jl")
# using .ImmerseCompose
include("display_gadfly.jl")
# using .DisplayGadfly

# Generic (?)
include("hit_test.jl")
# using .HitTest
include("select.jl")

function __init__()
    Compose.link_cairo()
    
    #set white background for default Theme
    t = Theme()
    t.panel_fill = colorant"white"
    Gadfly.push_theme(t)
    
    pushdisplay(_display)
end

end # module
