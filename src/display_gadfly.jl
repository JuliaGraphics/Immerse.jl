module DisplayGadfly

using Gtk, GtkUtilities, ..Graphics, Colors

import Gadfly, Compose
import Gadfly: Plot, Aesthetics
import ..Immerse: find_tagged, bareobj, absolute_to_data

export
    Handle,
    Figure,
    closefig,
    closeall,
    figure,
    gcf,
    render_backend,
    set_limits!

const ppmm = 72/25.4   # pixels per mm FIXME? Get from backend? See dev2data.

# Display code was copied & modified from Winston. The original
# contributors to that code included Mike Nolta, Jameson Nash,
# @slangangular, and likely others.

# While figures are by default associated with Windows (each with a
# single Canvas), you can have multiple figures per window.
type Figure
    canvas::GtkCanvas
    prepped         # tuple, a pre-processed Plot to speed rendering
    cc::Compose.Context   # fully-rendered Plot (useful for hit-testing)

    function Figure(c::GtkCanvas, p::Plot)
        prepped = Gadfly.render_prepare(p)
        cc = render_finish(prepped; dynamic=false)
        new(c, prepped, cc)
    end
    Figure(c::GtkCanvas) = new(c)
end

_plot(prepped) = prepped[1]
_plot(fig::Figure) = _plot(fig.prepped)
_aes(prepped) = prepped[3]
_aes(fig::Figure) = _aes(fig.prepped)

type GadflyDisplay <: Display
    figs::Dict{Int,Figure}
    fig_order::Vector{Int}
    current_fig::Int
    next_fig::Int

    GadflyDisplay() = new(Dict{Int,Figure}(), Int[], 0, 1)
end

const _display = GadflyDisplay()
pushdisplay(_display)

Base.display(d::GadflyDisplay, f::Figure) = display(f.canvas, f)

function Base.display(d::GadflyDisplay, p::Plot)
    isempty(d.figs) && figure()
    f = curfig(d)
    if p.theme.background_color == nothing
        # FIXME: someday one will want to plot transparently.
        # Might be better for Gadfly to default to :auto, and then each
        # renderer can pick how to resolve that (and reserve `nothing`
        # for users who want to turn off backgrounds manually).
        p.theme.background_color = colorant"white"
    end
    f.prepped = Gadfly.render_prepare(p)
    f.cc = render_finish(f.prepped; dynamic=false)
    display(f.canvas, f)
    f
end

function Base.display(c::GtkCanvas, f::Figure)
    c.draw = let bad=false
        function (_)
            bad && return
            viewx = get(guidata, (c, :viewx), nothing)
            if viewx != nothing
                viewy = guidata[c, :viewy]
                set_limits!(f, viewx, viewy)
            end
            # Render
            backend = render_backend(c)
            try
                guidata[c,:coords], guidata[c,:panelcoords] = Compose.draw(backend, f.cc)
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

function render_finish(prep; kwargs...)
    p = _plot(prep)
    root_context = Gadfly.render_prepared(prep...; kwargs...)

    ctx =  Compose.pad_inner(root_context, p.theme.plot_padding)

    if p.theme.background_color != nothing
        Compose.compose!(ctx, (Compose.context(order=-1000000),
                               Compose.fill(p.theme.background_color),
                               Compose.stroke(nothing), Compose.rectangle()))
    end

    return ctx
end

function set_ticks!(aes::Aesthetics, viewx, viewy)
    xtick = Gadfly.optimize_ticks(viewx.min, viewx.max)[1]
    ytick = Gadfly.optimize_ticks(viewy.min, viewy.max)[1]
    aes.xtick = aes.xgrid = xtick
    aes.ytick = aes.ygrid = ytick
    aes.xtickvisible = fill(true, length(xtick))
    aes.ytickvisible = fill(true, length(ytick))
    aes.xtickscale = ones(length(xtick))
    aes.ytickscale = ones(length(ytick))
    aes.xviewmin, aes.xviewmax = viewx.min, viewx.max
    aes.yviewmin, aes.yviewmax = viewy.min, viewy.max
    aes
end

function set_limits!(f::Figure, viewx, viewy)
    aes = _aes(f)
    if (aes.xviewmin, aes.xviewmax) != (viewx.min, viewx.max) ||
       (aes.yviewmin, aes.yviewmax) != (viewy.min, viewy.max)
        set_ticks!(aes, viewx, viewy)
        f.cc = render_finish(f.prepped; dynamic=false)
    end
    f
end

function dev2data(widget, x, y)
    xmm, ymm = x/ppmm, y/ppmm
    pc = guidata[widget,:panelcoords]
    @assert length(pc) == 1
    transform, unit_box, parent_box = pc[1]
    absolute_to_data(xmm, ymm, transform, unit_box, parent_box)
end

GtkUtilities.panzoom(f::Figure, args...) = panzoom(f.canvas, args...)
function GtkUtilities.panzoom(f::Figure)
    aes = _aes(f)
    viewx = (aes.xviewmin, aes.xviewmax)
    viewy = (aes.yviewmin, aes.yviewmax)
    panzoom(f.canvas, viewx, viewy)
end

function GtkUtilities.add_pan_mouse(f::Figure; kwargs...)
    aes = _aes(f)
    xflip = aes.xtick[end] < aes.xtick[1]
    yflip = aes.ytick[end] > aes.ytick[1]
    add_pan_mouse(f.canvas; fliphoriz=xflip, flipvert=yflip, kwargs...)
end

GtkUtilities.add_zoom_mouse(f::Figure; kwargs...) = add_zoom_mouse(f.canvas; user_to_data=(c,x,y)->dev2data(c,x,y), kwargs...)

function GtkUtilities.add_pan_key(f::Figure; kwargs...)
    aes = _aes(f)
    xflip = aes.xtick[end] < aes.xtick[1]
    yflip = aes.ytick[end] > aes.ytick[1]
    add_pan_key(f.canvas; fliphoriz=xflip, flipvert=yflip, kwargs...)
end

GtkUtilities.add_zoom_key(f::Figure; kwargs...) = add_zoom_key(f.canvas; kwargs...)

end # module
