# module ImmerseCompose

#import Base: start, next, done

# import Compose
using Measures: Vec, Measure, AbsoluteBox, resolve
using Compose: Backend
using Compose: Container, Context, Table
using Compose: Form, Line, Circle
using Compose: Property, Stroke, Fill, LineWidth, Visible, SVGClass
using Compose: List, ListNode, ListNull
using Compose: Transform, IdentityTransform, MatrixTransform, UnitBox
using Compose: absolute_native_units

start(l::List) = l
next(::List, l::List) = (l.head, l.tail)
done(::List, l::List) = typeof(l) <: ListNull
cons(value, l::List{T}) where T = ListNode{T}(value, l)

# using Compat, Colors #, GtkUtilities
# import Gtk

# export
#     find_object,
#     find_tagged,
#     find_panelforms,
#     find_inmask,
#     bareobj,
#     getproperty,
#     setproperty!,
#     nearest,
#     hitcenter,
#     absolute_to_data

const ContainersWithChildren = Table
const Iterables = Union{ContainersWithChildren, AbstractArray}

iterable(cnt::ContainersWithChildren) = cnt.children
iterable(a::AbstractArray) = a

# Testing utilities
#
# function test_by_drawing(c, obj, transform, units, box)
#     backend = Image{CairoBackend}(Main.Gtk.cairo_surface(c))
#     form = transform_form(transform, units, box, obj)
#     backend.stroke = RGBA(1.0,0,0,1.0)
#     Compose.draw(backend, form.primitives[1])
# end

# function transform_form(t::Transform, units::UnitBox,
#                         box::AbsoluteBox, form::Form)
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

function find_object(ctx::Context, tag)
    for item in ctx.form_children
        if has_tag(item, tag)
            return item
        end
    end
    for item in ctx.container_children
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

function _find_parent(obj::Context, tag)
    for item in obj.form_children
        if has_tag(item, tag)
            return true, obj
        end
    end
    for item in obj.container_children
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

function find_tagged!(handles, obj::Context)
    for item in obj.form_children
        if has_tag(item)
            handles[item.tag] = obj
        end
    end
    for item in obj.container_children
        find_tagged!(handles, item)
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

function find_path!(ret, ctx::Context, tag)
    for iter in (ctx.form_children, ctx.container_children)
        for item in iter
            if find_path!(ret, item, tag)
                push!(ret, item)
                return true
            end
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

# Finding all Forms in a plotpanel
# This is for working with untagged objects
find_panelforms(cnt) = find_panelforms!(Any[], cnt, false)

function find_panelforms!(forms, ctx::Context, inpanel::Bool)
    if !inpanel
        for child in ctx.property_children
            if isa(child, SVGClass) && length(child.primitives) == 1 && child.primitives[1].value == "plotpanel"
                inpanel = true
                break
            end
        end
        for child in ctx.container_children
            find_panelforms!(forms, child, inpanel)
        end
    else
        for child in ctx.form_children
            push!(forms, child)
        end
        for child in ctx.container_children
            find_panelforms!(forms, child, true)
        end
    end
    forms
end

function find_panelforms!(forms, cnt::Iterables, inpanel::Bool)
    for child in iterable(cnt)
        find_panelforms!(forms, child, inpanel)
    end
    forms
end

find_panelforms!(forms, obj, inpanel::Bool) = forms


function bareobj(ctx::Context)
    for c in ctx.form_children
        return c
    end
    error("No bareobj found in ", string_compact(ctx))
end
bareobj(f::Form) = f

# Modifying objects

sym2proptype(sym::Symbol) =
    sym == :stroke    ? Stroke :
    sym == :fill      ? Fill :
    sym == :linewidth ? LineWidth :
    sym == :visible   ? Visible :
    error(sym, " not a recognized property")

proptype2sym(::Type{Stroke})    = :stroke
proptype2sym(::Type{Fill})      = :fill
proptype2sym(::Type{LineWidth}) = :linewidth
proptype2sym(::Type{Visible})   = :visible

getproperty(ctx::Context, sym::Symbol) = getproperty(ctx, sym2proptype(sym))

function getproperty(ctx::Context, ::Type{P}, default=nothing) where {P<:Property}
    for c in ctx.property_children
        isa(c, P) && return _getvalue(c)
    end
    if default==nothing
        error(proptype2sym(P), " not found in ", string_compact(ctx))
    end
    return default
end
getproperty(ctx::Context, ::Type{Visible}) = getproperty(ctx, Visible, true)

_getvalue(p::Stroke)    = [prim.color for prim in p.primitives]
_getvalue(p::Fill)      = [prim.color for prim in p.primitives]
_getvalue(p::LineWidth) = [prim.value for prim in p.primitives]
_getvalue(p::Visible)   = [prim.value for prim in p.primitives]

setproperty!(ctx::Context, val, sym::Symbol) = setproperty!(ctx, val, sym2proptype(sym))

setproperty!(ctx::Context, val::Union{Colorant,AbstractString,AbstractArray}, ::Type{P}) where {P<:Stroke} =
    setproperty!(ctx, Compose.stroke(val))

setproperty!(ctx::Context, val::Union{Colorant,AbstractString,AbstractArray}, ::Type{P}) where {P<:Fill} =
    setproperty!(ctx, Compose.fill(val))

setproperty!(ctx::Context, val::Union{Measure,Number}, ::Type{P}) where {P<:LineWidth} =
    setproperty!(ctx, Compose.linewidth(val))

setproperty!(ctx::Context, val::Bool, ::Type{P}) where {P<:Visible} =
    setproperty!(ctx, Compose.visible(val))

function setproperty!(ctx::Context, val::P) where {P<:Property}
    ctx.property_children = _setproperty!(ctx.property_children, val)
    ctx
end

# Substitutes or adds a new property node in the list of children
function _setproperty!(iter, val::P, i) where {P}
    if done(iter, i)
        # add a node
        return ListNode{Property}(val, i)
    end
    item, inew = next(iter, i)
    if isa(item, P)
        # replace the node
        return ListNode{Property}(val, inew)
    end
    ListNode{Property}(item, _setproperty!(iter, val, inew))
end
_setproperty!(iter, val) = _setproperty!(iter, val, start(iter))

function string_compact(obj)
    io = IOBuffer()
    showcompact(io, obj)
    takebuf_string(io)
end

# Absolute-to-relative coordinate transformations
function absolute_to_data(x, y, transform, unit_box::UnitBox, parent_box::AbsoluteBox)
    xt, yt = invert_transform(transform, x, y)
    (unit_box.x0 + unit_box.width *(xt-parent_box.x0[1])/Measures.width(parent_box),
     unit_box.y0 + unit_box.height*(yt-parent_box.x0[2])/Measures.height(parent_box))
end

invert_transform(::IdentityTransform, x, y) = x, y

function invert_transform(t::MatrixTransform, x, y)
    @assert t.M[3,1] == t.M[3,2] == 0
    xyt = t.M\[x, y, 1.0]
    xyt[1], xyt[2]
end

# Iterators/functions that report object specs in native (screen) units
# These are useful for hit-testing

abstract type FormIterator end

struct FormNativeIterator{F<:Form,B<:Backend,C} <: FormIterator
    form::F
    backend::B
    coords::C
end

start(iter::FormNativeIterator) = 1  # some will specialize this
done(iter::FormNativeIterator, state::Int) = state > length(iter.form.primitives)
done(iter::FormNativeIterator, state::Tuple{Int,Int}) = state[1] > length(iter.form.primitives)

native(form::F, backend::B, coords::C) where {F,B,C} = FormNativeIterator{F,B,C}(form, backend, coords)

@inline inc(state::Tuple{Int,Int}, len::Int) =
    ifelse(state[2]+1 > len, (state[1]+1, 1), (state[1], state[2]+1))

# Scalars and points
function native(m::Measure, backend::Backend, coords)
    box, units, transform = coords
    absolute_native_units(backend, resolve(box, units, transform, m))
end

function native(m::Tuple{Measure,Measure}, backend::Backend, coords)
    box, units, transform = coords
    absolute_native_units(backend, resolve(box, units, transform, m))
end

# Iteration for specific Forms
start(::FormNativeIterator{F}) where {F<:Line} = (1,1)
function next(iter::FormNativeIterator{F}, state) where {F<:Line}
    nxy = native(iter.form.primitives[state[1]].points[state[2]], iter.backend, iter.coords)
    nxy, inc(state, length(iter.form.primitives[state[1]].points))
end

@inline function next(iter::FormNativeIterator{F}, state) where {F<:Circle}
    prim = iter.form.primitives[state]
    nx, ny = native(prim.center, iter.backend, iter.coords)
    nr = native(prim.radius, iter.backend, iter.coords)
    (nx, ny, nr), state+1
end


# Hit testing
function nearest(backend::Backend, coords, form::Circle, x, y)
    box, units, transform = coords
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

# Here we don't use the iterator because we need to break it out by segments
# Return index is (iline, isegment, fraction) where 0.0 <= fraction <= 1.0
# measures the fraction of the distance along the isegment-th segment
# of the nearest point to the click.
function nearest(backend::Backend, coords, form::Line, x, y)
    box, units, transform = coords
    mindist = Inf
    mini = (0,0,0.0)
    for iline = 1:length(form.primitives)
        thisline = form.primitives[iline]
        length(thisline.points) < 2 && continue
        nxold, nyold = native(thisline.points[1], backend, coords)
        skipping = false
        for isegment = 1:length(thisline.points)-1
            nx, ny = native(thisline.points[isegment+1], backend, coords)
            len = Float64(sqrt((nx-nxold)^2 + (ny-nyold)^2)) # length of segment
            if len == 0
                # The two points defining the segment are the same,
                # we'll report that it's either the incoming or outgoing
                # segment unless there are no other segments
                if !skipping || length(thisline.points)>isegment+1
                    skipping = true
                    continue
                end
                skipping = false
                dist = Float64(sqrt((nx-x)^2 + (ny-y)^2))
                if dist < mindist
                    mindist = dist
                    mini = (iline, isegment, 0.0)
                end
            else
                skipping = false
                # Compute the projection of (x,y) onto the segment
                vx, vy = (nx-nxold)/len, (ny-nyold)/len  # unit vector tanget
                l = (x-nxold)*vx + (y-nyold)*vy
                frac = l/len
                px, py = l*vx+nxold, l*vy+nyold
                nxold, nyold = nx, ny
                0.0 <= frac <= 1.0 || continue
                # Compute the distance
                dist = Float64(sqrt((px-x)^2 + (py-y)^2))
                if dist < mindist
                    mindist = dist
                    mini = (iline, isegment, frac)
                end
            end

        end
    end
    mindist, mini
end


function hitcenter(backend::Backend, coords, form::Line, index)
    prim = form.primitives[index[1]]
    frac = index[3]
    idx = index[2] + (frac >= 0.5 ? 1 : 0)
    pt = prim.points[idx]
    native(pt, backend, coords)
end

function hitcenter(backend, coords, form::Circle, index)
    circ = form.primitives[index]
    native(circ.center, backend, coords)
end

# selection by mask
function find_inmask(backend::Backend, coords, form::Circle, mask)
    index = Int[]
    for (i, nxyr) in enumerate(native(form, backend, coords))
        nx, ny, nr = nxyr
        inx, iny = round(Int, nx), round(Int, ny)
        1 <= inx <= size(mask,1) && 1 <= iny <= size(mask,2) || continue
        if mask[inx,iny]
            push!(index, i)
        end
    end
    index
end

function find_inmask(backend::Backend, coords, form::Line, mask)
    index = Tuple{Int,Int}[]
    iter = native(form, backend, coords)
    i = start(iter)
    while !done(iter, i)
        nxy, i = next(iter, i)
        nx, ny = nxy
        inx, iny = round(Int, nx), round(Int, ny)
        1 <= inx <= size(mask,1) && 1 <= iny <= size(mask,2) || continue
        if mask[inx,iny]
            push!(index, i)
        end
    end
    index
end


# end # module
