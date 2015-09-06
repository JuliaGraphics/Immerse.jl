module DisplayGadfly

using Gtk, GtkUtilities, Cairo
import Gadfly, Compose
import Gadfly: Plot
import ..Immerse: find_tagged

export
    Handle,
    Figure,
    closefig,
    closeall,
    figure,
    gcf,
    render_backend

# Display code was copied & modified from Winston. The original
# contributors to that code included Mike Nolta, Jameson Nash,
# @slangangular, and likely others.

# Handles keep a reference to a specific graphical element
# and also point to the enclosing figure. This means you
# can pass an object handle and gain access to everything
# you need for drawing.
immutable Handle{F}
    obj::Compose.Context  # inner object Context, not outer Plot Context
    figure::F
end

Base.show(io::IO, h::Handle) = print(io, bareobj(h.obj).tag, " handle")

# While figures are by default associated with Windows (each with a
# single Canvas), you can have multiple figures per window.
type Figure
    canvas::GtkCanvas
    cc::Compose.Context
    handles::Dict{Symbol,Handle{Figure}}

    function Figure(c::GtkCanvas, plot::Plot)
        cc = Gadfly.render(plot)
        f = new(c, cc)
        set_handles!(f)
    end
    Figure(c::GtkCanvas) = new(c)
end

function set_handles!(f)
    bare_handles = find_tagged(f.cc)
    handles = Dict{Symbol,Handle{Figure}}()
    for (k,v) in bare_handles
        handles[k] = Handle(v,f)
    end
    f.handles = handles
    f
end

Base.getindex(f::Figure, tag::Symbol) = f.handles[tag]

type GadflyDisplay <: Display
    figs::Dict{Int,Figure}
    fig_order::Vector{Int}
    current_fig::Int
    next_fig::Int
    GadflyDisplay() = new(Dict{Int,Figure}(), Int[], 0, 1)
end

const _display = GadflyDisplay()
pushdisplay(_display)

Base.display(d::GadflyDisplay, f::Figure) = display(f.canvas, f.cc)

function Base.display(d::GadflyDisplay, p::Plot)
    isempty(d.figs) && figure()
    f = curfig(d)
    f.cc = Gadfly.render(p)
    set_handles!(f)
    display(d, f)
    f
end

function Base.display(c::GtkCanvas, cc::Compose.Context)
    c.draw = let bad=false
        function (_)
            bad && return
            ctx = getgc(c)
            # Fill with a white background
            set_source_rgb(ctx, 1, 1, 1)
            paint(ctx)
            # Render
            backend = render_backend(c)
            try
                guidata[c,:coords] = Compose.draw(backend, cc)
            catch e
                bad = true
                rethrow(e)
                # println("Immerse error: ", e.msg)
            end
        end
    end
    Gtk.draw(c)
end

# Co-opt the REPL display
Base.display(::Base.REPL.REPLDisplay, ::MIME"text/html", p::Plot) = display(p)

render_backend(c) = Compose.Image{Compose.CairoBackend}(Gtk.cairo_surface(c))

function addfig(d::GadflyDisplay, i::Int, fig::Figure)
    @assert !haskey(d.figs,i)
    d.figs[i] = fig
    push!(d.fig_order, i)
    while haskey(d.figs,d.next_fig)
        d.next_fig += 1
    end
    d.current_fig = i
end

hasfig(d::GadflyDisplay, i::Int) = haskey(d.figs,i)

function switchfig(d::GadflyDisplay, i::Int)
    haskey(d.figs,i) && (d.current_fig = i)
end

function getfig(d::GadflyDisplay, i::Int)
    haskey(d.figs,i) ? d.figs[i] : error("no figure with index $i")
end

function curfig(d::GadflyDisplay)
    d.figs[d.current_fig]
end

nextfig(d::GadflyDisplay) = d.next_fig

function dropfig(d::GadflyDisplay, i::Int)
    haskey(d.figs,i) || return
    delete!(d.figs, i)
    splice!(d.fig_order, findfirst(d.fig_order,i))
    d.next_fig = min(d.next_fig, i)
    d.current_fig = isempty(d.fig_order) ? 0 : d.fig_order[end]
end

function figure(;name::String="Figure $(nextfig(_display))",
                 width::Integer=400,    # TODO: make configurable
                 height::Integer=400)
    i = nextfig(_display)
    w = gtkwindow(name, width, height, (x...)->dropfig(_display,i))
    addfig(_display, i, Figure(w))
end

function figure(i::Integer)
    switchfig(_display, i)
    fig = curfig(_display)
    display(_display, fig)
    Gtk.present(Gtk.toplevel(fig.canvas))
    nothing
end

gcf() = _display.current_fig
closefig() = closefig(_display.current_fig)

closefig(i::Integer) = gtkdestroy(getfig(_display,i).canvas)
closeall() = (map(closefig, keys(_display.figs)); nothing)

function gtkwindow(name, w, h, closecb=nothing)
    c = @GtkCanvas()
    win = @GtkWindow(c, name, w, h)
    if closecb !== nothing
        Gtk.on_signal_destroy(closecb, win)
    end
    showall(c)
end

function gtkdestroy(c::GtkCanvas)
    Gtk.destroy(Gtk.toplevel(c))
    nothing
end

end # module
