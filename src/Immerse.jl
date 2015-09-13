__precompile__()

module Immerse

using GtkUtilities, Colors, Reexport
@reexport using Gadfly
import Gtk   # because both Gadfly and Gtk define draw
import Compose

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
    hit

# Stuff for Gadfly/Compose
include("compose.jl")
using .ImmerseCompose
include("display_gadfly.jl")
using .DisplayGadfly

# Generic (?)
include("hit_test.jl")
# using .HitTest

end # module
