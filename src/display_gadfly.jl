module DisplayGadfly

using GtkUtilities, ..Graphics, Colors

import Gadfly, Compose, Gtk
import Gadfly: Plot, Aesthetics
import Gtk: GtkCanvas
import ..Immerse
import ..Immerse: absolute_to_data

export
    Figure,
    closefig,
    closeall,
    figure,
    gcf,
    scf,
    render_backend,
    set_limits!

const ppmm = 72/25.4   # pixels per mm FIXME? Get from backend? See dev2data.

immutable PanZoomCallbacks
    idpzk::UInt64
end

PanZoomCallbacks() = PanZoomCallbacks(0)
initialized(pzc::PanZoomCallbacks) = pzc.idpzk != 0

# Display code was copied & modified from Winston. The original
# contributors to that code included Mike Nolta, Jameson Nash,
# @slangangular, and likely others.

# While figures are by default associated with Windows (each with a
# single Canvas), you can have multiple figures per window.
type Figure
    canvas::GtkCanvas
    prepped         # tuple, a pre-processed Plot to speed rendering
    cc::Compose.Context   # fully-rendered Plot (useful for hit-testing)
    panzoom_cb::PanZoomCallbacks
    figno::Int

    function Figure(c::GtkCanvas, p::Plot)
        prepped = Gadfly.render_prepare(p)
        cc = render_finish(prepped; dynamic=false)
        new(c, prepped, cc, PanZoomCallbacks())
    end
    Figure(c::GtkCanvas) = new(c, nothing, Compose.Context(), PanZoomCallbacks())
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

Base.display(d::GadflyDisplay, f::Figure) = display(f.canvas, f)

function Base.display(d::GadflyDisplay, p::Plot)
    isempty(d.figs) && figure()
    f = curfig(d)
    # Clear data that might have applied to the previous plot
    clear_hit(f)
    clear_guidata(f.canvas)
    # Supply a background, if not present
    if p.theme.background_color == nothing
        # FIXME: someday one will want to plot transparently.
        # Might be better for Gadfly to default to :auto, and then each
        # renderer can pick how to resolve that (and reserve `nothing`
        # for users who want to turn off backgrounds manually).
        p.theme.background_color = colorant"white"
    end
    # Do most of the time-consuming parts of plotting
    f.prepped = Gadfly.render_prepare(p)
    # Render in the current state
    f.cc = render_finish(f.prepped; dynamic=false)
    # Render the figure
    display(f.canvas, f)
    gcf()
end

function Base.display(c::GtkCanvas, f::Figure)
    c.draw = let bad=false
        function (_)
            bad && return
            xview = get(guidata, (c, :xview), nothing)
            if xview != nothing
                yview = guidata[c, :yview]
                set_limits!(f, xview, yview)
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

const _hit_data = Dict{Figure,Dict{Symbol,Any}}()

clear_hit(fig::Figure) = delete!(_hit_data, fig)

function addfig(d::GadflyDisplay, i::Int, fig::Figure)
    @assert !haskey(d.figs,i)
    d.figs[i] = fig
    push!(d.fig_order, i)
    while haskey(d.figs,d.next_fig)
        d.next_fig += 1
    end
    d.current_fig = i
    fig.figno = i
end

hasfig(d::GadflyDisplay, i::Int) = haskey(d.figs,i)

function switchfig(d::GadflyDisplay, i::Int)
    haskey(d.figs,i) && (d.current_fig = i)
end

function getfig(d::GadflyDisplay, i::Int)
    haskey(d.figs,i) ? d.figs[i] : error("no figure with index $i")
end
"""
`Figure(3)` gets the underlying Figure object associated with figure #3.
This can be useful if you need to layer on extra drawing on top of what
Gadfly produces.
"""
Figure(i::Int) = getfig(_display, i)

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

"""
`figure(;name="Figure \$n", width=400, height=400)` creates a new
figure window for displaying plots.

`figure(n)` raises the `n`th figure window and makes it the current
default plotting window, and returns the
"""
function figure(;name::String="Figure $(nextfig(_display))",
                 width::Integer=400,    # TODO: make configurable
                 height::Integer=400)
    i = nextfig(_display)
    c = gtkwindow(name, width, height, (x...)->dropfig(_display,i))
    f = Figure(c)
    Gtk.signal_connect(guidata[c,:save_as], "clicked") do widget
        save_as(f)
    end
    Gtk.signal_connect(guidata[c,:zoom_button], "clicked") do widget
        panzoom_cb(f)
    end
    Gtk.signal_connect(guidata[c,:fullview], "clicked") do widget
        fullview_cb(f)
    end
    Immerse.lasso_initialize(f)
    addfig(_display, i, f)
end

function figure(i::Integer)
    switchfig(_display, i)
    fig = curfig(_display)
    display(_display, fig)
    Gtk.present(Gtk.toplevel(fig.canvas))
    fig
end

"`gcf()` (\"get current figure\") returns the current figure number"
gcf() = _display.current_fig

"`scf()` (\"show current figure\") raises (makes visible) the current figure"
scf() = figure(gcf())

"""
`closefig(n)` closes the `n`th figure window.

`closefig()` closes the current figure window.
"""
closefig() = closefig(_display.current_fig)

closefig(i::Integer) = (fig = getfig(_display,i); clear_hit(fig); gtkdestroy(getfig(_display,i).canvas))

"`closeall()` closes all existing figure windows."
closeall() = (map(closefig, keys(_display.figs)); nothing)

function gtkwindow(name, w, h, closecb=nothing)
    box = Gtk.@GtkBox(:v)
    tb = Gtk.@GtkToolbar()
    push!(box, tb)
    save_as = Gtk.@GtkToolButton("gtk-save-as")     # document-save-as
    zb = Gtk.@GtkToggleToolButton("gtk-find")       # edit-find
    fullview = Gtk.@GtkToolButton("gtk-zoom-100")   # zoom-original
    lasso_button = Gtk.@GtkToggleToolButton()
    Gtk.GAccessor.icon_widget(lasso_button, Gtk.@GtkImage(joinpath(HOME, "images", "lasso_icon.png")))
    push!(tb, save_as)
    push!(tb, Gtk.@GtkSeparatorToolItem())
    push!(tb, zb)
    push!(tb, fullview)
    push!(tb, Gtk.@GtkSeparatorToolItem())
    push!(tb, lasso_button)
    c = Gtk.@GtkCanvas()
    Gtk.setproperty!(c, :expand, true)
    push!(box, c)
    guidata[c, :save_as] = save_as
    guidata[c, :zoom_button] = zb
    guidata[c, :fullview] = fullview
    guidata[c, :lasso_button] = lasso_button
    win = Gtk.@GtkWindow(box, name, w, h)
    guidata[win, :toolbar] = tb
    if closecb !== nothing
        Gtk.on_signal_destroy(closecb, win)
    end
    showall(win)
    c
end

function clear_guidata(c)
    gd = guidata[c]
    to_delete = Array(Symbol, 0)
    for (k,v) in gd
        if !(k in [:save_as, :zoom_button, :fullview, :lasso_button])
            push!(to_delete, k)
        end
    end
    for k in to_delete
        delete!(gd, k)
    end
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

function set_ticks!(aes::Aesthetics, xview, yview)
    xtick = Gadfly.optimize_ticks(xview.min, xview.max)[1]
    ytick = Gadfly.optimize_ticks(yview.min, yview.max)[1]
    aes.xtick = aes.xgrid = xtick
    aes.ytick = aes.ygrid = ytick
    aes.xtickvisible = fill(true, length(xtick))
    aes.ytickvisible = fill(true, length(ytick))
    aes.xtickscale = ones(length(xtick))
    aes.ytickscale = ones(length(ytick))
    aes.xviewmin, aes.xviewmax = xview.min, xview.max
    aes.yviewmin, aes.yviewmax = yview.min, yview.max
    aes
end

function set_limits!(f::Figure, xview, yview)
    aes = _aes(f)
    if (aes.xviewmin, aes.xviewmax) != (xview.min, xview.max) ||
       (aes.yviewmin, aes.yviewmax) != (yview.min, yview.max)
        set_ticks!(aes, xview, yview)
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
    xview = (aes.xviewmin, aes.xviewmax)
    yview = (aes.yviewmin, aes.yviewmax)
    panzoom(f.canvas, xview, yview)
end

function GtkUtilities.panzoom_mouse(f::Figure; kwargs...)
    aes = _aes(f)
    xflip = aes.xtick[end] < aes.xtick[1]
    yflip = aes.ytick[end] > aes.ytick[1]
    panzoom_mouse(f.canvas; xpanflip=xflip, ypanflip=yflip, user_to_data=(c,x,y)->dev2data(c,x,y), kwargs...)
end

function GtkUtilities.panzoom_key(f::Figure; kwargs...)
    aes = _aes(f)
    xflip = aes.xtick[end] < aes.xtick[1]
    yflip = aes.ytick[end] > aes.ytick[1]
    panzoom_key(f.canvas; xpanflip=xflip, ypanflip=yflip, kwargs...)
end

function block(f::Figure, pcz::PanZoomCallbacks)
    c = f.canvas
    Gtk.signal_handler_block(c, pcz.idpzk)
    pop!((c.mouse,:scroll))
    pop!((c.mouse,:button1press))
end

function unblock(f::Figure, pcz::PanZoomCallbacks)
    Gtk.signal_handler_unblock(f.canvas, pcz.idpzk)
    panzoom_mouse(f)
end

function PanZoomCallbacks(f::Figure)
    panzoom(f)
    panzoom_mouse(f)
    PanZoomCallbacks(panzoom_key(f))
end

const file_backends = Dict(".svg"=>Compose.SVG, ".png"=>Compose.PNG, ".pdf"=>Compose.PDF, ".ps"=>Compose.PS)

function save_as(f::Figure)
    extensions = (".svg", ".png", ".pdf", ".ps")
    selection = Gtk.save_dialog("Save figure as file", Gtk.toplevel(f.canvas), map(x->string("*",x), extensions))
    isempty(selection) && return nothing
    basename, ext = splitext(selection)
    if !in(ext, extensions)
        Gtk.error_dialog("Extension $ext not recognized: use .svg, .png, .pdf, or .ps")
        return nothing
    end
    w, h = width(f.canvas), height(f.canvas)
    Compose.draw(file_backends[ext](selection, w*Compose.px, h*Compose.px), f.cc)
    nothing
end

function panzoom_cb(f::Figure)
    if !initialized(f.panzoom_cb)
        f.panzoom_cb = PanZoomCallbacks(f)
    else
        state = Gtk.getproperty(guidata[f.canvas, :zoom_button], :active, Bool)
        if state
            unblock(f, f.panzoom_cb)
        else
            block(f, f.panzoom_cb)
        end
    end
end

function fullview_cb(f::Figure)
    if initialized(f.panzoom_cb)
        GtkUtilities.zoom_reset(f.canvas)
    end
end

const HOME = splitdir(splitdir(@__FILE__)[1])[1]

function __init__()
    pushdisplay(_display)
end

end # module
