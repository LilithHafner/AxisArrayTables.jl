module AxisArrayTables

using Tables: Tables
using PrettyTables: pretty_table
using AxisArrays: AxisArrays, AxisArray, (..)
using ShiftedArrays: ShiftedArrays, lead, lag
using CSV: CSV, write

export AxisArrayTable, .., lead, lag, row_labels, column_labels

abstract type AbstractAxisArrayTable{T} <: AbstractMatrix{T} end

struct AxisArrayTable{T, U <: AxisArray{T, 2}} <: AbstractAxisArrayTable{T}
    data::U
    AxisArrayTable(data::AxisArray{T, 2}) where T = new{T, typeof(data)}(data)
end
function AxisArrayTable(data::AbstractMatrix, rows::AbstractVector, cols::Vector{Symbol}; check_unique::Bool=true)
    check_unique && !allunique(cols) && throw(ArgumentError("Column names must be unique"))
    AxisArrayTable(AxisArray(data; rows, cols))
end
function AxisArrayTable(table) # Very inefficient
    rows = Tables.getcolumn(Tables.columns(table), 1)
    cols = Tables.columnnames(table)[2:end]
    data = Tables.matrix((;ntuple(i -> Symbol(i) => Tables.getcolumn(table, i+1), length(cols))...))
    AxisArrayTable(data, rows, cols)
end

# getter method to avoid conflict with custom getproperty method
data(m::AxisArrayTable) = getfield(m, :data)
Base.parent(m::AxisArrayTable) = parent(data(m))

# named axes
named_axes(m::AbstractAxisArrayTable) = getproperty.(data(m).axes, :val)
row_labels(m::AbstractAxisArrayTable) = named_axes(m)[1]
column_labels(m::AbstractAxisArrayTable) = named_axes(m)[2]

# Access by dot syntax `data.var3`
Base.propertynames(m::AbstractAxisArrayTable) = column_labels(m)
Base.getproperty(m::AbstractAxisArrayTable, col::Symbol) = getindex(m, :, col)

# Conform to the AbstractMatrix interface
# https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-array

# Required
Base.size(m::AbstractAxisArrayTable) = size(data(m))
function Base.getindex(m::AbstractAxisArrayTable, inds...) # Access keeps the same type (uncommon design decision); with and exception for m[today(),:b] === 7
    a = data(m)
    ix = AxisArrays.to_index(a, inds...)
    all(i -> i isa Integer, ix) && return AxisArrays.getindex_converted(a, ix...)
    AxisArrayTable(AxisArrays.getindex_converted(a, (i isa Integer ? (i:i) : i for i in ix)...))
end
Base.setindex!(m::AbstractAxisArrayTable, val, inds...) = setindex!(data(m), val, inds...)

# Optional
Base.similar(m::AbstractAxisArrayTable, T::Type=eltype(m)) = AxisArrayTable(similar(data(m), T), row_labels(m), column_labels(m), check_unique=false)

# Conform to the Tables.jl interface
# https://tables.juliadata.org/stable/#Implementing-the-Interface-(i.e.-becoming-a-Tables.jl-source)

# Required as a Table
Tables.istable(::Type{<:AbstractAxisArrayTable}) = true
Tables.columnaccess(::Type{<:AbstractAxisArrayTable}) = true
Tables.columns(m::AbstractAxisArrayTable) = m

# Required as a Tables.AbstractColumns
Tables.getcolumn(m::AbstractAxisArrayTable, i::Int) = data(m)[:, i]
Tables.getcolumn(m::AbstractAxisArrayTable, s::Symbol) = data(m)[:, s]

# Customize broadcasting `data .+ data`
# https://docs.julialang.org/en/v1/manual/interfaces/#man-interfaces-broadcasting
# https://julialang.org/blog/2018/05/extensible-broadcast-fusion/
# TODO revise and test error messages

# Insert hook
struct AxisArrayTableStyle <: Broadcast.BroadcastStyle end
Base.BroadcastStyle(::Type{<:AbstractAxisArrayTable}) = AxisArrayTableStyle()

function Base.copy(bc::Broadcast.Broadcasted{AxisArrayTableStyle})
    rc = named_axes(bc) # error before computation
    data = copy(Broadcast.Broadcasted{Broadcast.DefaultArrayStyle{2}}(bc.f, bc.args, bc.axes)) # leverage default matrix behavior
    AxisArrayTable(data, rc...) # wrap the result in the same rich axes
end

# Recursively determine rich axis data and error if there is a discrepancy
named_axes(_) = nothing
named_axes(bc::Broadcast.Broadcasted{AxisArrayTableStyle}) = combine_axes(map(named_axes, bc.args)...)

combine_axes(x) = x
combine_axes(x, y, args...) = combine_axes(combine_axes(x, y), args...)
combine_axes(::Nothing, ::Nothing) = nothing
combine_axes(::Nothing, x) = x
combine_axes(x, ::Nothing) = x
combine_axes(x, y) = x == y ? x : axis_mismatch_error(x,y)
function axis_mismatch_error(x, y)
    i = findfirst(x .!= y)
    throw(ArgumentError("AxesArrayTables may only be broadcast when their axis labels are equal. Got:\n    $(x[i]) and\n    $(y[i])"))
end

# Establish precedence (prefer AxisArrayTable over Array & throw on 3+ dimensions)
Base.BroadcastStyle(::AxisArrayTableStyle, ::Broadcast.AbstractArrayStyle{T}) where T =
    T <= 2 ? AxisArrayTableStyle() : throw(DimensionMismatch("AxisArrayTable cannot be broadcast with AbstractArray{T, $T}"))

# Error message reference
# function Broadcast.result_style(s1::AxisArrayTableStyle, s2::AxisArrayTableStyle)
#     s1.cols == s2.cols || throw(ArgumentError("Broadcasting over mismatched columns is not supported"))
#     s1.rows == s2.rows || throw(ArgumentError("Broadcasting over mismatched rows is not supported"))
#     s1
# end

# Pretty printing
Base.show(io::IO, m::AbstractAxisArrayTable) = pretty_table(io, m, row_labels=row_labels(m))
Base.show(io::IO, ::MIME"text/plain", m::AbstractAxisArrayTable) = show(io, m) # needed because AxisArrayTable <: AbstractMatrix

# Custom "do what I mean" indexing
Base.getindex(m::AbstractAxisArrayTable, cols::AbstractVector{<:Symbol}) = getindex(m, :, cols)
Base.getindex(m::AbstractAxisArrayTable, cols::Vararg{Symbol}) = getindex(m, :, collect(cols))
Base.getindex(m::AbstractAxisArrayTable, col::Symbol) = getindex(m, :, col)
Base.setindex!(m::AbstractAxisArrayTable, v, cols::AbstractVector{<:Symbol}) = setindex!(m, v, :, cols)
Base.setindex!(m::AbstractAxisArrayTable, v, cols::Vararg{Symbol}) = setindex!(m, v, :, collect(cols))
Base.setindex!(m::AbstractAxisArrayTable, v, col::Symbol) = setindex!(m, v, :, col)

# Compatibility with shifted arrays functions
ShiftedArrays.lead(m::AbstractAxisArrayTable, args...) = AxisArrayTable(lead(data(m), args...), named_axes(m)...)
ShiftedArrays.lag(m::AbstractAxisArrayTable, args...) = AxisArrayTable(lag(data(m), args...), named_axes(m)...)
Base.diff(m::AbstractAxisArrayTable, args...) = m - lag(m, args...)

# Dynamically merge tables and adjust axes as needed
function Base.merge(tables::Vararg{AbstractAxisArrayTable}) # TODO revise for simplicity and performance
    r = union(row_labels.(tables)...)
    c = merge_colnames(tables...)
    data = Matrix{Union{eltype.(tables)..., Missing}}(undef, length(r), length(c))
    data .= missing
    res = AxisArrayTable(data, r, c, check_unique=false)

    i = 0
    for t in tables, col in column_labels(t)
        i += 1
        for row in row_labels(t) # Inefficient design due to upstream issue https://github.com/JuliaArrays/AxisArrays.jl/issues/212
            res[row, i] = t[row, col]
        end
    end

    res
end
function merge_colnames(tables...)
    res = Vector{Symbol}(undef, sum(length ∘ column_labels, tables))
    seen = Set{Symbol}()
    for t in tables, c in column_labels(t)
        c2 = if c ∈ seen
            i = 2
            while Symbol(c, i) ∈ seen
                i += 1
            end
            Symbol(c, i)
        else
            c
        end
        push!(seen, c2)
        res[length(seen)] = c2
    end
    res
end

# Add row labels as a column to support saving to file when the row_labels keyword is unavailable
table_with_row_labels(m::AbstractAxisArrayTable; row_label_header=:time) =
    (; Symbol(row_label_header)=>row_labels(m), (name=>view(m, :, i) for (i,name) in enumerate(column_labels(m)))...)
CSV.write(file, m::AbstractAxisArrayTable; row_label_header=:time, kw...) =
    CSV.write(file, table_with_row_labels(m; row_label_header); kw...)

end
