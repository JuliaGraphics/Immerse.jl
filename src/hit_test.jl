# module HitTest

# using Gtk, GtkUtilities, ..Graphics, Colors
# import Compose
# import ..Immerse: nearest, hitcenter, Figure, render_backend, find_object

# export
#     hit,
#     circle_center

import .DisplayGadfly: _hit_data

"""
`hit((fig,tag), cb)` turns on hit-testing for the plot element tagged with `tag` in figure `fig`. When the user clicks on the element, the callback function `cb` will be executed.

The callback should have the form

```jl
    function my_callback(figtag, index, xy, distance)
        if distance < 2
            # We clicked close enough to the object to "count"
            # implement the action here
        end
    end
```

`xy = (x,y)` is the position of the click in screen-pixels. `distance`
measures how much the user "missed" the object, and is also measured
in screen-pixels. `index` represents the specific item clicked on.
This might be a single `Int`, or for compound objects might be a more
complex object.

Here are a couple of examples:
```jl
    fig = display(plot(x=1:10,y=rand(10),Geom.point(tag=:dots)))
    hit((fig,:dots), (figtag, index, xy, dist) -> if dist < 1 println("You clicked on dot ", index) end)
```
In this case, `index` will be an `Int`.

```jl
    x = rand(6)
    y = rand(6)
    label = [1,1,1,1,2,2]
    df = DataFrame(Any[x,y,label], [:x,:y,:label])
    fig = display(plot(df, x=:x, y=:y, color=:label, Geom.line(tag=:lines)))

    hit((fig,:lines), (figtag, index, xy, dist) -> begin
        if dist < 2
            println("You clicked on line ", index[1], " in segment ", index[2], " at \$(round(Int,100*index[3]))% along the segment")
        end
    end)
```
"""
function hit(figtag::Tuple{Int,Symbol}, cb)
    figno, tag = figtag
    fig = Figure(figno)
    if !haskey(_hit_data, fig)
        _hit_data[fig] = Dict{Symbol,Any}()
        c = fig.canvas
        c.mouse.button1press = Gtk.@guarded (widget, event) -> begin
            if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
                hitcb(figno, fig, event.x, event.y)
            end
        end
    end
    _hit_data[fig][tag] = (true, cb)   # starts in "on" position
    nothing
end

function hit(figtag::Tuple{Int,Symbol}, state::Bool)
    dct = _hit_data[fig]
    olddata = dct[tag]
    dct[tag] = (state, olddata.cb)
    nothing
end


# callback function for hit-testing
function hitcb(figno, f, x, y)
    c = f.canvas
    hitables = get(_hit_data, f, nothing)
    hitables == nothing && return
    coords = GtkUtilities.guidata[c, :coords]
    mindist = Inf
    minindex = 0   # not type-stable, unfortunately
    obj = Compose.empty_tag
    backend = render_backend(c)
    local objcb
    for (tag, data) in hitables
        state, cb = data
        !state && continue
        # Find the object in the rendered figure
        form = find_object(f.cc, tag)
        dist, index = nearest(backend, coords[tag], form, x, y)
        if dist < mindist
            mindist = dist
            obj = tag
            objcb = cb
            minindex = index
        end
    end
    if obj != Compose.empty_tag
        objcb((figno,obj), minindex, (x,y), mindist)
    end
    nothing
end

# A good callback function for testing
#    hit(figtag, (figtag, index, xy, dist) -> circle_center(figtag, index))
function circle_center(figtag::Tuple{Int,Symbol}, index; color=RGB{U8}(1,0,0))
    figno, tag = figtag
    f = Figure(figno)
    c = f.canvas
    coords = GtkUtilities.guidata[c, :coords][tag]
    form = find_object(f.cc, tag)
    backend = render_backend(c)
    x, y = hitcenter(backend, coords, form, index)
    ctx = getgc(c)
    set_source(ctx, color)
    set_line_width(ctx, 2)
    arc(ctx, x, y, 5, 0, 2pi)
    stroke(ctx)
    Gtk.reveal(c)
    nothing
end

# end  # module
