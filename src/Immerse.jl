__precompile__()

module Immerse

using GtkUtilities, Colors, Reexport, Compat, REPL
@reexport using Gadfly
import Gtk   # because both Gadfly and Gtk define draw
import Compose, Measures
using Cairo

@eval Compose begin import Cairo end
Compose.link_cairo()

if VERSION < v"0.4.0-dev"
    using Base.Graphics
else
    using Graphics
end

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

end # module
