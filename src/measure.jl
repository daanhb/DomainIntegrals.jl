
export support,
    domaintype,
    codomaintype,
    isdiscrete,
    iscontinuous,
    isnormalized,
    weightfun,
    weightfunction,
    points,
    weights,
    weight


"Supertype of measures."
abstract type Measure{T} end

domaintype(μ::Measure) = domaintype(typeof(μ))
domaintype(::Type{<:Measure{T}}) where {T} = T

"What is the codomain type of the measure?"
codomaintype(μ::Measure) = codomaintype(typeof(μ))
codomaintype(::Type{<:Measure{T}}) where {T} = prectype(T)

prectype(::Type{<:Measure{T}}) where {T} = prectype(T)
numtype(::Type{<:Measure{T}}) where {T} = numtype(T)

"Is the measure normalized?"
isnormalized(μ::Measure) = false

# conversion to `Measure{T}` is a means to ensure a specific domain type `T`
convert(::Type{Measure{T}}, μ::Measure{T}) where {T} = μ
convert(::Type{Measure{T}}, μ::Measure{S}) where {S,T} = similar(μ, T)


"""
A `Weight` is a continuous measure that is defined in terms of a weight
function: `dμ = w(x) dx`.
"""
abstract type Weight{T} <: Measure{T} end


"""
A `DiscreteWeight` is a measure defined in terms of a discrete set of points
and an associated set of weights.

The measure implements the `points` and `weights` functions. The support of
a discrete measure may be a continuous domain that includes all of the points.
"""
abstract type DiscreteWeight{T} <: Measure{T} end

"Is the measure discrete?"
isdiscrete(μ::Weight) = false
isdiscrete(μ::DiscreteWeight) = true
# We don't know the result for an abstract Measure,
# so we can't provide a default here

"Is the measure continuous?"
iscontinuous(μ::Weight) = true
iscontinuous(μ::DiscreteWeight) = false
# Like above, no default



###############################
## Continuous weight functions
###############################


# We define the functionality at the level of `Measure`, since not
# all continuous measures are of type `Weight`.
# This implementation is typically safe, as invoking these functions on a
# discrete measur is likely to result in an error (because it does not implement
# a weight function).

"Return the support of the continuous measure"
support(μ::Measure{T}) where {T} = FullSpace{T}()

"Evaluate the weight function associated with the measure."
function weightfun(μ::Measure{T}, x::S) where {S,T}
    U = promote_type(S,T)
    weightfun(convert(Measure{U}, μ), convert(U, x))
end

# If the argument x is a vector: ensure the element types match
function weightfun(μ::Measure{Vector{S}}, x::AbstractVector{T}) where {S,T}
    U = promote_type(S,T)
    weightfun(convert(Weight{Vector{U}}, μ), convert(AbstractVector{U}, x))
end
# If the measure expects SVector, convert x to SVector (we can assume matching eltype)
weightfun(μ::Measure{SVector{N,S}}, x::AbstractVector{T}) where {N,S,T} =
    weightfun(μ, convert(SVector{N,S}, x))

# Accept matching types, and matching vectors
weightfun(μ::Measure{T}, x::T) where {T} = weightfun1(μ, x)
weightfun(μ::Measure{Vector{T}}, x::AbstractVector{T}) where {T} =
    weightfun1(μ, x)
weightfun(μ::Measure{SVector{N,T}}, x::SVector{N,T}) where {N,T} =
    weightfun1(μ, x)

# Check for support, then invoke unsafe_weight
weightfun1(μ::Measure, x) =
    x ∈ support(μ) ? unsafe_weightfun(μ, x) : zero(codomaintype(μ))

# These are safe defaults for any measure
weightfunction(μ::Measure) = x->weightfun(μ, x)
unsafe_weightfunction(μ::Measure) = x->unsafe_weightfun(μ, x)


####################
## Discrete weights
####################

# The main interface: return the points and weights of the discrete measure
points(μ::DiscreteWeight) = μ.points
weights(μ::DiscreteWeight) = μ.weights
support(μ::DiscreteWeight) = μ.domain

length(μ::DiscreteWeight) = length(points(μ))
size(μ::DiscreteWeight) = size(points(μ))

isnormalized(μ::DiscreteWeight) = sum(weights(μ)) ≈ 1


# Discrete weights are equal if their points and weights are equal elementwise
Base.:(==)(μ1::DiscreteWeight, μ2::DiscreteWeight) =
    points(μ1) == points(μ2) && weights(μ1)==weights(μ2)
Base.:(≈)(μ1::DiscreteWeight, μ2::DiscreteWeight) =
    points(μ1) ≈ points(μ2) && weights(μ1) ≈ weights(μ2)


function weight(μ::DiscreteWeight, i)
    # Perform a bounds check and invoke unsafe_discrete_weight,
    # so that concrete measures may implement e.g. an on-the-fly formula for
    # the weights without bounds checking
    @boundscheck checkbounds(μ, i)
    unsafe_weight(μ, i)
end
checkbounds(μ::DiscreteWeight, i) = checkbounds(points(μ), i)

function unsafe_weight(μ::DiscreteWeight, i)
    @inbounds weights(μ)[i]
end


"A generic discrete weight that stores points and weights."
struct GenericDiscreteWeight{T,P,W,D} <: DiscreteWeight{T}
    points  ::  P
    weights ::  W
    domain  ::  D
end

GenericDiscreteWeight(points, weights,domain) =
    GenericDiscreteWeight{eltype(weights)}(points, weights,domain)
GenericDiscreteWeight{T}(points::P, weights::W,domain::D) where {T,P,W,D} =
    GenericDiscreteWeight{T,P,W,D}(points, weights, domain)
