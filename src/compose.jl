module ImmerseCompose

import Base: start, next, done

import Compose
import Compose: Context, Table, Form, Backend, CairoBackend, Transform, IdentityTransform, Property, Container, ContainerPromise, Point, Image, AbsoluteBoundingBox, UnitBox, Stroke, Fill, ListNode, ComposeNode, ParentDrawContext, MatrixTransform, Measure, MeasureNil
import Compose: Line, Circle, SVGClass

using Compat, Colors #, GtkUtilities

export
    find_object,
    find_tagged,
    handle,
    bareobj,
    getproperty,
    setproperty!,
    nearest,
    hitcenter,
    absolute_to_data,
    device_to_data

typealias ContainersWithChildren Union(Context,Table)
typealias Iterables Union(ContainersWithChildren, AbstractArray)

iterable(ctx::ContainersWithChildren) = ctx.children
iterable(a::AbstractArray) = a

# Override Compose's drawing to keep track of coordinates of tagged objects
function Compose.draw(backend::Backend, root_canvas::Context)
    coords, panelcoords = Main.Immerse.ImmerseCompose.drawpart(backend, root_canvas)
    Compose.finish(backend)
    coords, panelcoords
end

# Copied from Compose, adding the coords output
function drawpart(backend::Backend, root_container::Container)
    S = Any[(root_container, IdentityTransform(), UnitBox(), Compose.root_box(backend))]

    # used to collect property children
    properties = Array(Property, 0)

    # collect and sort container children
    container_children = Array((@compat Tuple{Int, Int, Container}), 0)

    # store coordinates of tagged objects and plotpanels
    coords = Dict{Symbol,Any}()
    panelcoords = Any[]  # FIXME?: tables (subplotgrid)

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
            if isa(child, SVGClass) && length(child.primitives) == 1 && child.primitives[1].value == "plotpanel"
                push!(panelcoords, (transform, units, box))
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
    coords, panelcoords
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

# Absolute-to-relative coordinate transformations
function device_to_data(backend::Backend, x, y, transform, unit_box::UnitBox, parent_box::AbsoluteBoundingBox)
    xmm, ymm = x/backend.ppmm, y/backend.ppmm
    absolute_to_data(x, y, transform, unit_box, parent_box)
end

function absolute_to_data(x, y, transform, unit_box::UnitBox, parent_box::AbsoluteBoundingBox)
    xt, yt = invert_transform(transform, x, y)
    (unit_box.x0 + unit_box.width *(xt-parent_box.x0)/parent_box.width,
     unit_box.y0 + unit_box.height*(yt-parent_box.y0)/parent_box.height)
end

invert_transform(::IdentityTransform, x, y) = x, y

function invert_transform(t::MatrixTransform, x, y)
    @assert t.M[3,1] == t.M[3,2] == 0
    xyt = t.M\[x, y, 1.0]
    xyt[1], xyt[2]
end


# Iterators/functions that report object specs in native (screen) units
# These are useful for hit-testing

abstract FormIterator

immutable FormNativeIterator{F<:Form,B<:Backend,C} <: FormIterator
    form::F
    backend::B
    coords::C
end

start(iter::FormNativeIterator) = 1  # some will specialize this
done(iter::FormNativeIterator, state::Int) = state > length(iter.form.primitives)
done(iter::FormNativeIterator, state::Tuple{Int,Int}) = state[1] > length(iter.form.primitives)

native{F,B,C}(form::F, backend::B, coords::C) = FormNativeIterator{F,B,C}(form, backend, coords)

@inline inc(state::Tuple{Int,Int}, len::Int) =
    ifelse(state[2]+1 > len, (state[1]+1, 1), (state[1], state[2]+1))

# Scalars and points
function native(m::Measure, backend::Backend, coords)
    transform, units, box = coords
    z  = Compose.absolute_units(m, transform, units, box)
    Compose.absolute_native_units(backend, z)
end

function native(pt::Point, backend::Backend, coords)
    transform, units, box = coords
    pabs = Compose.absolute_units(pt, transform, units, box)
    nx = Compose.absolute_native_units(backend, pabs.x.abs)
    ny = Compose.absolute_native_units(backend, pabs.y.abs)
    (nx, ny)
end

# Iteration for specific Forms
start{F<:Line}(::FormNativeIterator{F}) = (1,1)
function next{F<:Line}(iter::FormNativeIterator{F}, state)
    nxy = native(iter.form.primitives[state[1]].points[state[2]], iter.backend, iter.coords)
    nxy, inc(state, length(iter.form.primitives[state[1]].points))
end

@inline function next{C<:Compose.CirclePrimitive}(iter::FormNativeIterator{Form{C}}, state)
    prim = iter.form.primitives[state]
    nx, ny = native(prim.center, iter.backend, iter.coords)
    nr = native(prim.radius, iter.backend, iter.coords)
    (nx, ny, nr), state+1
end


# Hit testing
function nearest(backend::Backend, coords, form::Line, x, y)
    transform, units, box = coords
    mindist = Inf
    mini = (0,0)
    iter = native(form, backend, coords)
    state = start(iter)
    while !done(iter, state)
        oldstate = state
        nxy, state = next(iter, state)
        nx, ny = nxy
        dist = Float64((nx-x)^2 + (ny-y)^2)
        if dist < mindist
            mindist = dist
            mini = oldstate
        end
    end
    sqrt(mindist), mini
end

function nearest{C<:Compose.CirclePrimitive}(backend::Backend, coords, form::Form{C}, x, y)
    transform, units, box = coords
    mindist = Inf
    mini = 0
    for (i,nxyr) in enumerate(native(form, backend, coords))
        nx, ny, nr = nxyr
        dist = Float64((nx-x)^2 + (ny-y)^2 - nr^2)
        if dist < mindist
            mindist = max(0.0, dist)
            mini = i
        end
    end
    sqrt(mindist), mini
end


function hitcenter(backend::Backend, coords, form::Line, index)
    prim = form.primitives[index[1]]
    pt = prim.points[index[2]]
    native(pt, backend, coords)
end

function hitcenter{C<:Compose.CirclePrimitive}(backend, coords, form::Form{C}, index)
    circ = form.primitives[index]
    native(circ.center, backend, coords)
end

end # module
