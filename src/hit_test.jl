const _hit_canvases = Dict{Gtk.GtkCanvas,Set{Any}}()
const _hit_obj = Dict()

objcoords(c, obj) = GtkUtilities.guidata[c, :coords][bareobj(obj).tag]

function hit(c::Gtk.GtkCanvas, obj, cb)
    bobj = bareobj(obj)
    if !haskey(_hit_canvases, c)
        _hit_canvases[c] = Set()
    end
    push!(_hit_canvases[c], bobj)
    _hit_obj[bobj] = cb
    c.mouse.button1press = (widget, event) -> begin
        if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
            hitcb(widget, event.x, event.y)
        end
    end
end

function hit(c::Gtk.GtkCanvas, obj, state::Bool)
    state == false || error("must supply a callback function")
    bobj = bareobj(obj)
    delete!(_hit_obj, bobj)
    delete!(_hit_canvases[c], bobj)
    nothing
end

hit(f::Figure, obj, state::Bool) = hit(f.canvas, obj, state)
hit(f::Figure, obj, state)       = hit(f.canvas, obj, state)

function hitcb(c, x, y)
    hitables = _hit_canvases[c]
    coords = GtkUtilities.guidata[c, :coords]
    mindist = Inf
    obj = nothing
    itemindex, entryindex = 0, 0
    backend = render_backend(c)
    for ht in hitables
        dist, iindex, eindex = nearest(backend, coords[ht.tag], ht, x, y)
        if dist < mindist
            mindist = dist
            obj = ht
            itemindex = iindex
            entryindex = eindex
        end
    end
    cb = _hit_obj[obj]
    cb(mindist, itemindex, entryindex)
end

# A good callback function for testing
#    hit(c, obj, (mindist, itemindex, entryindex) -> circle_center(c, obj, itemindex, entryindex))
function circle_center(c, obj, itemindex, entryindex; color=RGB{U8}(1,0,0))
    coords = objcoords(c, obj)
    backend = render_backend(c)
    x, y = hitcenter(backend, coords, bareobj(obj), itemindex, entryindex)
    ctx = Cairo.getgc(c)
    set_source(ctx, color)
    set_line_width(ctx, 2)
    arc(ctx, x, y, 5, 0, 2pi)
    stroke(ctx)
    Gtk.reveal(c)
    nothing
end
