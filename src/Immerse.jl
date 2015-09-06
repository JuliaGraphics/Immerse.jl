module Immerse

import Gadfly, Compose, Gtk, GtkUtilities
using Colors, Cairo

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
