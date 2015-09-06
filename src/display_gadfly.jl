module DisplayGadfly

using Gtk, GtkUtilities, Cairo
import Gadfly, Compose
import Gadfly: Plot

export
    Figure,
    closefig,
    closeall,
    figure,
    gcf,
    render_backend,
    handle

# Display code was copied from Winston. The original contributors
# to that code included Mike Nolta, Jameson Nash, @slangangular,
# and likely others.

type Figure
    canvas::GtkCanvas
    cc::Compose.Context
end
Figure(c::GtkCanvas, plot::Plot) = Figure(c, Gadfly.render(plot))

handle(f::Figure, tag) = handle(f.cc, tag)

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

Base.display(d::GadflyDisplay, p::Plot) = display(d, Gadfly.render(p))

function Base.display(d::GadflyDisplay, cc::Compose.Context)
    isempty(d.figs) && figure()
    f = curfig(d)
    f.cc = cc
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

const empty_cc = Compose.Context()
current_cc = empty_cc

function figure(;name::String="Figure $(nextfig(_display))",
                 width::Integer=400,    # TODO: make configurable
                 height::Integer=400)
    i = nextfig(_display)
    w = gtkwindow(name, width, height, (x...)->dropfig(_display,i))
    if isempty(_display.figs)
        global current_cc = empty_cc
    end
    addfig(_display, i, Figure(w,current_cc))
end

function figure(i::Integer)
    switchfig(_display, i)
    fig = curfig(_display)
    global current_cc = fig.cc
    display(_display, fig.cc)
    Gtk.present(Gtk.toplevel(c))
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
