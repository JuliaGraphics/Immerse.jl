# import .ImmerseCompose: Iterables, iterable, native
# import .DisplayGadfly: Figure, render_backend
import Compose: SVGClass, Form, Circle, Line, Backend
# using Gtk, Cairo, GtkUtilities

path2mask(backend::Backend, pathx, pathy) = path2mask(round(Int,width(Compose.surface(backend))), round(Int,height(Compose.surface(backend))), pathx, pathy)

function path2mask(w, h, pathx, pathy)
    length(pathx) == length(pathy) || error("pathx and pathy must have the same length")
    if isempty(pathx)
        return falses(w, h)
    end
    # Use Cairo to make the mask
    data = Array{UInt32}(undef, w, h)
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
    push!((c.mouse,:button1press), Gtk.@guarded (widget,event) -> begin
        empty!(pathx)
        empty!(pathy)
        push!(pathx, event.x)
        push!(pathy, event.y)
        push!((c.mouse,:button1motion), dragging)
    end)
    push!((c.mouse,:button1release), Gtk.@guarded (widget,event) -> begin
        # Restore the original mouse handlers
        pop!((c.mouse, :button1press))
        pop!((c.mouse, :button1motion))
        pop!((c.mouse, :button1release))
        # Toggle the lasso selection button
        lasso_button = guidata[c, :lasso_button]
        setproperty!(lasso_button, :active, false)
        # Redraw the canvas
        Gtk.draw(c)
        select_points(f, pathx, pathy)
    end)
end

Gtk.@guarded function dragging(widget,event)
    ctx = getgc(widget)
    move_to(ctx, pathx[end], pathy[end])
    line_to(ctx, event.x, event.y)
    set_source_rgb(ctx, 0, 0, 0)
    stroke(ctx)
    push!(pathx, event.x)
    push!(pathy, event.y)
    Gtk.reveal(widget, false)
end

function select_points(f::Figure, pathx, pathy)
    c = f.canvas
    # Check to see if the figure is empty (issue #56)
    isempty(f) && return nothing
    # Find the forms
    forms = find_panelforms(f.cc)
    # Create the mask
    backend = render_backend(c)
    mask = path2mask(backend, pathx, pathy)
    # Determine which points are in the mask
    coords = guidata[c,:panelcoords][1]
    selections = Dict()
    for form in forms
        selections[form] = find_inmask(backend, coords, form, mask)
    end
    # Run the callback
    lasso_button = guidata[c, :lasso_button]
    cb = guidata[lasso_button, :callback]
    cb(f.figno, selections)
end

const lasso_default = (figno, selections) -> export_selection(selections)

"""

`lasso_initialize(figno, cb)` sets the callback `cb` to run when the
user has selected points with the lasso.  When you have only one
"object" (Geom) in your plot, your callback can be of the form
```
    function my_simple_lasso_callback(figno, selections)
        println("You selected points ", first(values(selections)))
    end
```
For a `Geom.point` object, this would print a vector of integers
corresponding to the selected points.

More generally, the callback should have the syntax
```
    function my_lasso_callback(figno, selections)
        for (form, indexes) in selections
            if form.tag == :mydots
                println("In figure \$figno, from :mydots you selected ", indexes)
            end
        end
    end
```
`selections` is a `Dict` of `form=>indexes` pairs.  `form` is a
`Compose.Form`, the raw objects rendered by Gadfly; you may especially
want to query its `tag` to determine its identity (assuming you've
assigned a tag).  `indexes` is a vector describing the items selected;
for `Circle` forms, each element will be an `Int`, whereas for `Line`
Forms (which can hold multiple lines, perhaps drawn in different colors)
each element will be an `Tuple{Int,Int}` describing the line number
and vertex number.

To assign a tag to a Gadfly object, add the `tag` keyword argument to
the geometry, e.g. `Geom.point(tag = :mydots)`.
"""
function lasso_initialize(f::Figure, cb=lasso_default)
    c = f.canvas
    lasso_button = guidata[c, :lasso_button]
    guidata[lasso_button, :callback] = cb
    # Work around Gtk #161 & #185
    # Gtk.signal_connect(lasso_button, "clicked") do widget
    #     lasso_select_cb(f)
    # end
    #Gtk.signal_connect(lasso_wrapper, lasso_button, "clicked", Void, (), false, f)
end
lasso_initialize(i::Int, cb=lasso_default) = lasso_initialize(Figure(i), cb)

Gtk.@guarded function lasso_wrapper(widgetptr::Ptr, f)
    widget = convert(Gtk.GtkToggleToolButtonLeaf, widgetptr)
    if Gtk.get_gtk_property(widget, :active, Bool)
        lasso_select_cb(f)
    end
    nothing
end

function export_selection(selections)
    # Extract (tag,index) pairs. We don't use a Dict in case there are
    # multiple untagged objects.
    indexes = Array{Tuple{Symbol,Any}}(undef,length(selections))
    i = 0
    nonempty = false
    for (form,indx) in selections
        indexes[i+=1] = (form.tag,indx)
        nonempty |= !isempty(indx)
    end
    nonempty || return nothing
    resp, varname = Gtk.input_dialog("Pick variable name in Main for exporting selection", "selection", (("Cancel",0), ("Store",1)))
    if resp == 0
        return nothing
    end
    if !isempty(varname)
        sym = Symbol(varname)
        eval(Main, :($sym = $indexes))
    end
    nothing
end
