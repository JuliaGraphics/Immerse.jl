module Immerse

import Gadfly, Compose, Gtk, GtkUtilities
using Colors
if VERSION < v"0.4.0-dev"
    using Base.Graphics
else
    using Graphics
end

import Gtk: GtkCanvas

export
    closefig,
    closeall,
    figure,
    gcf,
    handle,
    hit,
    getproperty,
    setproperty!

# Stuff for Gadfly/Compose
include("compose.jl")
using .ImmerseCompose
include("display_gadfly.jl")
using .DisplayGadfly

# Generic (?)
include("hit_test.jl")

end # module
