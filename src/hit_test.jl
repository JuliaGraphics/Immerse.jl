module HitTest

using Gtk, GtkUtilities, ..Graphics, Colors
import Compose
import ..Immerse: nearest, hitcenter, Figure, render_backend, find_object

export
    hit,
    circle_center

const _hit_data = Dict{Figure,Dict{Symbol,Any}}()

function hit(fig::Figure, tag::Symbol, cb)
    if !haskey(_hit_data, fig)
        _hit_data[fig] = Dict{Symbol,Any}()
        c = fig.canvas
        c.mouse.button1press = @guarded (widget, event) -> begin
            if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
                hitcb(fig, event.x, event.y)
            end
        end
    end
    _hit_data[fig][tag] = (true, cb)   # starts in "on" position
    nothing
end

function hit(fig::Figure, tag::Symbol, state::Bool)
    dct = _hit_data[c]
    olddata = dct[tag]
    dct[tag] = (state, olddata.cb)
    nothing
end

# callback function for hit-testing
function hitcb(f, x, y)
    c = f.canvas
    hitables = _hit_data[f]
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
        objcb(mindist, minindex)
    end
    nothing
end

# A good callback function for testing
#    hit(fig, tag, (mindist, index) -> circle_center(fig, tag, index))
function circle_center(f::Figure, tag, index; color=RGB{U8}(1,0,0))
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

end  # module
