module ImmerseCompose

import Compose
import Compose: Context, Table, Form, Backend, CairoBackend, Transform, IdentityTransform, Property, Container, ContainerPromise, Point, Image, AbsoluteBoundingBox, UnitBox, Stroke, Fill, ListNode, ComposeNode, ParentDrawContext
import Compose: LinePrimitive

using Compat, Colors #, GtkUtilities

export
    find_tagged,
    handle,
    bareobj,
    getproperty,
    setproperty!,
    nearest,
    hitcenter

typealias ContainersWithChildren Union(Context,Table)
typealias Iterables Union(ContainersWithChildren, AbstractArray)

iterable(ctx::ContainersWithChildren) = ctx.children
iterable(a::AbstractArray) = a

# Override Compose's drawing to keep track of coordinates of tagged objects
function Compose.draw(backend::Backend, root_canvas::Context)
    coords = Main.Immerse.ImmerseCompose.drawpart(backend, root_canvas)
    Compose.finish(backend)
    coords
end

# Copied from Compose, adding the coords output
function drawpart(backend::Backend, root_container::Container)
    S = Any[(root_container, IdentityTransform(), UnitBox(), Compose.root_box(backend))]

    # used to collect property children
    properties = Array(Property, 0)

    # collect and sort container children
    container_children = Array((@compat Tuple{Int, Int, Container}), 0)

    # store coordinates of tagged objects
    coords = Dict{Symbol,Any}()

    while !isempty(S)
        s = pop!(S)

        # Groups of properties are in a property frame, analogous to a stack
        # frame. A marker is pushed to the stack so we know when to pop the
        # frame.
        if s == :POP_PROPERTY_FRAME
            Compose.pop_property_frame(backend)
            continue
        end

        container, parent_transform, units, parent_box = s

        if (Compose.iswithjs(container) && !Compose.iswithjs(backend)) ||
           (Compose.iswithoutjs(container) && Compose.iswithjs(backend))
            continue
        end

        if isa(container, ContainerPromise)
            container = Compose.realize(container,
                                ParentDrawContext(parent_transform, units, parent_box))
            if !isa(container, Container)
                error("Error: A container promise function did not evaluate to a container")
            end
            push!(S, (container, parent_transform, units, parent_box))
            continue
        end

        @assert isa(container, Context)
        ctx = container

        box = Compose.absolute_units(ctx.box, parent_transform, units, parent_box)
        rot = Compose.absolute_units(ctx.rot, parent_transform, units, box)
        transform = Compose.combine(convert(Transform, rot), parent_transform)

        if ctx.mir != nothing
            mir = Compose.absolute_units(ctx.mir, parent_transform, units, box)
            transform = Compose.combine(convert(Transform, mir), transform)
        end

        if ctx.raster && isdefined(:Cairo) && isa(backend, SVG)
            # TODO: commented out while I search for the real source of the
            # slowness, cause it it ain't this.
            bitmapbackend = PNG(box.width, box.height, false)
            draw(bitmapbackend, ctx)
            f = bitmap("image/png", takebuf_array(bitmapbackend.out),
                       0, 0, 1w, 1h)

            c = context(ctx.box.x0, ctx.box.y0,
                        ctx.box.width, ctx.box.height,
                        units=UnitBox(),
                        order=ctx.order,
                        clip=ctx.clip)
            push!(S, (compose(c, f), parent_transform, units, parent_box))
            continue
        end

        if ctx.units != Compose.nil_unit_box
            units = Compose.absolute_units(ctx.units, transform, units, box)
        end

        for child in ctx.children
            if isa(child, Property)
                push!(properties, Compose.absolute_units(child, parent_transform, units, parent_box))
            end
        end

        if ctx.clip
            x0 = ctx.box.x0
            y0 = ctx.box.y0
            x1 = x0 + ctx.box.width
            y1 = y0 + ctx.box.height
            push!(properties,
                  Compose.absolute_units(Compose.clip(Point(x0, y0), Point(x1, y0),
                                                      Point(x1, y1), Point(x0, y1)),
                                 parent_transform, units, parent_box))
        end

        if !isempty(properties)
            Compose.push_property_frame(backend, properties)
            push!(S, :POP_PROPERTY_FRAME)
            empty!(properties)
        end

        for child in ctx.children
            if isa(child, Form)
                Compose.draw(backend, transform, units, box, child)
                if child.tag != Compose.empty_tag
                    coords[child.tag] = (transform, units, box)
                end
            end
        end

        for child in ctx.children
            if isa(child, Container)
                push!(container_children,
                      (Compose.order(child), 1 + length(container_children), child))
            end
        end
        sort!(container_children, rev=true)

        for (_, _, child) in container_children
            push!(S, (child, transform, units, box))
        end
        empty!(container_children)
    end
    coords
end

# Testing utilities
#
# function test_by_drawing(c, obj, transform, units, box)
#     backend = Image{CairoBackend}(Main.Gtk.cairo_surface(c))
#     form = transform_form(transform, units, box, obj)
#     backend.stroke = RGBA(1.0,0,0,1.0)
#     Compose.draw(backend, form.primitives[1])
# end

# function transform_form(t::Transform, units::UnitBox,
#                         box::AbsoluteBoundingBox, form::Form)
#     Form([Compose.absolute_units(primitive, t, units, box)
#                                for primitive in form.primitives])
# end


# For now only Forms have tags, but this may change

# Find a tagged object
function find_object(cnt::Iterables, tag)
    for item in iterable(cnt)
        if has_tag(item, tag)
            return item
        end
        ret = find_object(item, tag)
        if ret != nothing
            return ret
        end
    end
    nothing
end

find_object(obj, tag) = nothing

# Find a tagged object's parent Context
function find_parent(root, tag)
    found, ret = _find_parent(root, tag)
    found == false && error(tag, " not found")
    ret
end

function _find_parent(obj::Iterables, tag)
    for item in iterable(obj)
        if has_tag(item, tag)
            return true, obj
        end
        found, ret = _find_parent(item, tag)
        found && return found, ret
    end
    false, obj
end

_find_parent(obj, tag) = false, obj

# Find the enclosing Context (parent) of all tagged Forms
function find_tagged(root)
    handles = Dict{Symbol,Context}()
    find_tagged!(handles, root)
end

function find_tagged!(handles, obj::Iterables)
    for item in iterable(obj)
        if has_tag(item)
            handles[item.tag] = obj
        else
            find_tagged!(handles, item)
        end
    end
    handles
end

find_tagged!(handles, obj) = obj

# Find the nested series of containers leading to a tagged object
function find_path(root::Context, tag)
    ret = Any[]
    find_path!(ret, root, tag)
    ret
end

function find_path!(ret, cnt::Iterables, tag)
    for item in iterable(cnt)
        if find_path!(ret, item, tag)
            isa(item, Array) || push!(ret, item)
            return true
        end
    end
    false
end

find_path!(ret, form::Form, tag) = has_tag(form, tag)

find_path!(ret, obj, tag) = false


has_tag(form::Form, tag) = form.tag == tag
has_tag(form::Form)      = form.tag != Compose.empty_tag

has_tag(obj, tag) = false
has_tag(obj)      = false


handle(ctx::Context, tag) = find_parent(ctx, tag)

function bareobj(ctx::Context)
    for c in ctx.children
        if isa(c, Form)
            return c
        end
    end
    error("No bareobj found in ", string_compact(ctx))
end
bareobj(f::Form) = f

# Modifying objects

sym2proptype(sym::Symbol) =
    sym == :stroke ? Stroke :
    sym == :fill   ? Fill :
    error(sym, " not a recognized property")

proptype2sym(::Type{Stroke}) = :stroke
proptype2sym(::Type{Fill})   = :fill

getproperty(ctx::Context, sym::Symbol) = getproperty(ctx, sym2proptype(sym))

function getproperty{P<:Property}(ctx::Context, ::Type{P})
    for c in ctx.children
        isa(c, P) && return c
    end
    error(proptype2sym(P), " not found in ", string_compact(ctx))
end

setproperty!(ctx::Context, val, sym::Symbol) = setproperty!(ctx, val, sym2proptype(sym))

setproperty!{P<:Stroke}(ctx::Context, val::Union(Colorant,String,AbstractArray), ::Type{P}) =
    setproperty!(ctx, Compose.stroke(val))

function setproperty!{P<:Property}(ctx::Context, val::P)
    iter = ctx.children
    i = start(iter)
    ctx.children = _setproperty!(iter, val, i)
    ctx
end

function _setproperty!{P}(iter, val::P, i)
    done(iter, i) && error("no ", proptype2sym(P), " property found")
    item, inew = next(iter, i)
    if isa(item, P)
        return ListNode{ComposeNode}(val, inew)
    end
    ListNode{ComposeNode}(item, _setproperty!(iter, val, inew))
end

function string_compact(obj)
    io = IOBuffer()
    showcompact(io, obj)
    takebuf_string(io)
end

# Hit testing

# x, y are in device-coordinates, i.e., pixels
function nearest(backend::Backend, coords, form::Form, x, y)
    mindist = Inf
    itemindex, entryindex = 0, 0
    for (itemi,prim) in enumerate(form.primitives)
        dist, entryi = nearest(backend, coords, prim, x, y)
        if dist < mindist
            mindist = dist
            itemindex = itemi
            entryindex = entryi
        end
    end
    mindist, itemindex, entryindex
end

function nearest(backend::Backend, coords, prim::LinePrimitive, x, y)
    transform, units, box = coords
    mindist = Inf
    mini = 0
    for (i,pt) in enumerate(prim.points)
        pabs = Compose.absolute_units(pt, transform, units, box)
        px = Compose.absolute_native_units(backend, pabs.x.abs)
        py = Compose.absolute_native_units(backend, pabs.y.abs)
        dist = Float64((px-x)^2 + (py-y)^2)
        if dist < mindist
            mindist = dist
            mini = i
        end
    end
    sqrt(mindist), mini
end

function hitcenter(backend::Backend, coords, form::Form, itemindex, entryindex)
    prim = form.primitives[itemindex]
    hitcenter(backend, coords, prim, entryindex)
end

function hitcenter(backend, coords, prim::LinePrimitive, entryindex)
    transform, units, box = coords
    pt = prim.points[entryindex]
    pabs = Compose.absolute_units(pt, transform, units, box)
    px = Compose.absolute_native_units(backend, pabs.x.abs)
    py = Compose.absolute_native_units(backend, pabs.y.abs)
    px, py
end

end # module
