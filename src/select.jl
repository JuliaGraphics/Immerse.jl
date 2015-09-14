import .ImmerseCompose: Iterables, iterable, native
import .DisplayGadfly: Figure, render_backend
import Compose: SVGClass, Form, Circle, Line, Backend
using Gtk, Cairo, GtkUtilities

path2mask(backend::Backend, pathx, pathy) = path2mask(round(Int,width(backend.surface)), round(Int,height(backend.surface)), pathx, pathy)

function path2mask(w, h, pathx, pathy)
    length(pathx) == length(pathy) || error("pathx and pathy must have the same length")
    if isempty(pathx)
        return falses(w, h)
    end
    # Use Cairo to make the mask
    data = Array(UInt32, w, h)
    surf = Cairo.CairoImageSurface(data, Cairo.FORMAT_RGB24, flipxy=false)
    ctx = CairoContext(surf)
    set_source_rgb(ctx, 0, 0, 0)
    paint(ctx)
    move_to(ctx, pathx[end], pathy[end])
    for i = 1:length(pathx)
        line_to(ctx, pathx[i], pathy[i])
    end
    set_source_rgb(ctx, 1, 1, 1)
    fill(ctx)
    mask = reshape([x & 0xff > 0 for x in data], size(data))
    mask
end

const pathx = Float64[]
const pathy = Float64[]

function lasso_select_cb(f::Figure)
    c = f.canvas
    push!((c.mouse,:button1press), @guarded (widget,event) -> begin
        empty!(pathx)
        empty!(pathy)
        push!(pathx, event.x)
        push!(pathy, event.y)
        push!((c.mouse,:button1motion), dragging)
    end)
    push!((c.mouse,:button1release), @guarded (widget,event) -> begin
        select_points(f, pathx, pathy)
    end)
end

@guarded function dragging(widget,event)
    ctx = getgc(widget)
    move_to(ctx, pathx[end], pathy[end])
    line_to(ctx, event.x, event.y)
    set_source_rgb(ctx, 0, 0, 0)
    stroke(ctx)
    push!(pathx, event.x)
    push!(pathy, event.y)
    reveal(widget, false)
end

function select_points(f::Figure, pathx, pathy)
    # Restore the original mouse handlers
    c = f.canvas
    pop!((c.mouse, :button1press))
    pop!((c.mouse, :button1motion))
    pop!((c.mouse, :button1release))
    # Toggle the lasso selection button
    lasso_button = guidata[c, :lasso_button]
    setproperty!(lasso_button, :active, false)
    # Redraw the canvas
    Gtk.draw(c)
    # Find the forms
    forms = find_panelforms(f.cc)
    # Create the mask
    backend = render_backend(c)
    mask = path2mask(backend, pathx, pathy)
    # Determine which points are in the mask
    coords = guidata[c,:panelcoords][1]
    inmask = Any[find_inmask(backend, coords, form, mask) for form in forms]
    # Run the callback
    cb = guidata[lasso_button, :callback]
    cb(forms, inmask)
end

const lasso_default = (forms,inmask)->export_selection(inmask)

function initialize_lasso(f::Figure, cb=lasso_default)
    c = f.canvas
    lasso_button = guidata[c, :lasso_button]
    guidata[lasso_button, :callback] = cb
    Gtk.signal_connect(lasso_button, "clicked") do widget
        lasso_select_cb(f)
    end
end
initialize_lasso(i::Int, cb=lasso_default) = initialize_lasso(Figure(i), cb)

function export_selection(indexes)
    all(isempty, indexes) && return nothing
    resp, varname = Gtk.input_dialog("Pick variable name in Main for exporting selection", "selection", (("Cancel",0), ("Store",1)))
    if resp == 0
        return nothing
    end
    if !isempty(varname)
        sym = symbol(varname)
        eval(Main, :($sym = $indexes))
    end
    nothing
end

# function input_dialog{S<:String}(messages::AbstractVector{S}, entries_default::AbstractVector{S}, buttons=(("Cancel",0), ("Accept",1)), parent = Gtk.GtkNullContainer())
#     length(messages) == length(entries_default) || error("Must have the same number of questions as answers
#     widget = Gtk.@GtkMessageDialog(message, buttons, Gtk.GtkDialogFlags.DESTROY_WITH_PARENT, Gtk.GtkMessageType.INFO)
#     box = content_area(widget)
#     entry = Array(Gtk.GtkEntryLeaf, lengtH
#     entry = Gtk.@Entry(;text=entry_default)
#     push!(box, entry)
#     showall(widget)
#     resp = run(widget)
#     entry_text = getproperty(entry, :text, ByteString)
#     destroy(widget)
#     return resp, entry_text
# end
