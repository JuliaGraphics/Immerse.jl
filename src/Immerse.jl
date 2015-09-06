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

# Stuff for Gadfly/Compose
include("display_gadfly.jl")
using .DisplayGadfly

end # module
