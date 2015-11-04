using Compat, Distributions, Debug
import Base: <=

#=
"""
Interval{T} is a typealias for Tuple{T,T}
"""
=#
typealias Interval{T} @compat Tuple{T,T}


#=
"""
Transform

Subtypes of the abstract Transform type indicate how a `Parameter`'s
value is transformed from model space (which can be bounded to a
limited section of the real line) to the entire real line (which is
necessary for mode-finding using csminwel). The transformation is
performed by the `toreal` function, and is reversed by the `tomodel`
function.
"""
=#
abstract Transform

immutable Untransformed <: Transform end
immutable SquareRoot    <: Transform end
immutable Exponential   <: Transform end

Base.show(io::IO, t::Untransformed) = @printf io "x -> x\n"
Base.show(io::IO, t::SquareRoot)    = @printf io "x -> (a+b)/2 + (b-a)/2*c*x/sqrt(1 + c^2 * x^2)\n"
Base.show(io::IO, t::Exponential)   = @printf io "x -> b + (1/c) * log(x-a)\n"



"""
AbstractParameter{T<:Number}

The AbstractParameter type is the common supertype of all model
parameters, including steady-state values that we treat as
parameters. Its subtype structure is as follows:

*`AbstractParameter{T<:Number}`
    *`Parameter{T<:Number, U<:Transform}`
        *`UnscaledParameter{T<:Number, U:<Transform}`
        *`ScaledParameter{T<:Number, U:<Transform}`
    *`SteadyStateParameter{T<:Number}`
"""
abstract AbstractParameter{T<:Number} 



"""
Parameter{T<:Number, U<:Transform} <: AbstractParameter{T}

The Parameter type is the common supertype of time-invariant,
non-steady-state model parameters. It has 2 subtypes,
`UnscaledParameter` and `ScaledParameter`. `ScaledParameter`s are
parameters whose values are scaled when used in the model's
equilibrium conditions. The scaled value is stored for convenience,
and udpated when the parameter's value is updated.
"""
abstract Parameter{T,U<:Transform} <: AbstractParameter{T}

typealias ParameterVector{T} Vector{AbstractParameter{T}}
typealias NullablePrior      Nullable{ContinuousUnivariateDistribution}


"""
UnscaledParameter{T<:Number,U<:Transform} <: Parameter{T,U}

Time-invariant model parameter whose value is used as-is in the model's equilibrium conditions (`eqcond`).

#### Fields
- `key::Symbol`: Parameter name. For maximum clarity, `key`
should conform to the guidelines established in the DSGE Style Guide.
- `value::T`: Parameter value. Initialized in model space (guaranteed
to be between `valuebounds`), but can be transformed between model
space and the real line via calls to `toreal` and `tomodel`.
- `valuebounds::Interval{T}`: Bounds for the parameter's value in model space.
- `transform_parameterization::Interval{T}`: Parameters used to
transform `value` between model space and the real line.
- `transform::U`: Transformation used to transform `value` between
model space and real line.
- `prior::NullablePrior`: Prior distribution for parameter value.
- `fixed::Bool`: Indicates whether the parameter's value is fixed rather than estimated.
- `description::AbstractString`:  A short description of the parameter's economic significance.
- `texLabel::AbstractString`: String for printing the parameter name to LaTeX.
"""
type UnscaledParameter{T,U} <: Parameter{T,U}
    key::Symbol
    value::T                             # parameter value in model space
    valuebounds::Interval{T}             # bounds of parameter value
    transform_parameterization::Interval{T}    # parameters for transformation
    transform::U                # transformation we use to go between model space and real line for csminwel
    prior::NullablePrior        # prior distribution
    fixed::Bool                 # is this parameter fixed at some value, or do we estimate it?
    description::AbstractString 
    texLabel::AbstractString    # LaTeX label for printing
end


"""
ScaledParameter{T,U} <: Parameter{T,U}

Time-invariant model parameter whose value is scaled for use in the model's equilibrium conditions (`eqcond`).

#### Fields

- `key::Symbol`: Parameter name. For maximum clarity, `key`
should conform to the guidelines established in the DSGE Style Guide.
- `value::T`: The parameter's unscaled value. Initialized in model
  space (guaranteed to be between `valuebounds`), but can be
  transformed between model space and the real line via calls to
  `toreal` and `tomodel`.
- `scaledvalue::T`: Parameter value scaled for use in `eqcond.jl`
- `valuebounds::Interval{T}`: Bounds for the parameter's value in model space.
- `transform_parameterization::Interval{T}`: Parameters used to
  transform `value` between model space and the real line.
- `transform::U`: The transformation used to convert `value` between model space and the real line, for use in csminwel.
- `prior::NullablePrior`: Prior distribution for parameter value.
- `fixed::Bool`: Indicates whether the parameter's value is fixed rather than estimated.
- `scaling::Function`: Function used to scale parameter value for use in equilibrium conditions.
- `description::AbstractString`: A short description of the parameter's economic significance.
- `texLabel::AbstractString`: String for printing parameter name to LaTeX.
"""
type ScaledParameter{T,U} <: Parameter{T,U}
    key::Symbol
    value::T 
    scaledvalue::T		
    valuebounds::Interval{T}    
    transform_parameterization::Interval{T}    
    transform::U               
    prior::NullablePrior
    fixed::Bool
    scaling::Function
    description::AbstractString
    texLabel::AbstractString
end

"""
SteadyStateParameter{T} <: AbstractParameter{T}

Steady-state model parameter whose value depends upon the value of
other (non-steady-state) `Parameter`s. `SteadyStateParameter`s must be
constructed and added to an instance of a model object `m` _after_ all
other model `Parameter`s have been defined. Once added to `m`,
`SteadyStateParameter`s are stored in `m.steady_state`. Their values
are calculated and set by `steadystate!(m)`, rather than being
estimated directly. `SteadyStateParameter`s do not require
transformations from the model space to the real line or scalings for
use in equilibrium conditions.

#### Fields

- `key::Symbol`: Parameter name. Should conform to the guidelines
established in the DSGE Style Guide.
- `value::T`: The parameter's steady-state value.
- `description::AbstractString`: Short description of the parameter's economic significance.
- `texLabel::AbstractString`: String for printing parameter name to LaTeX.
"""
type SteadyStateParameter{T} <: AbstractParameter{T}
    key::Symbol
    value::T                    
    description::AbstractString
    texLabel::AbstractString
end

hasprior(p::Parameter) = !isnull(p.prior)

typealias NullableOrPrior @compat(Union{NullablePrior, ContinuousUnivariateDistribution})

# We want to use value field from UnscaledParameters and
# SteadyStateParameters in computation, so we alias their union here.
typealias UnscaledOrSteadyState @compat(Union{UnscaledParameter, SteadyStateParameter})

"""
ParamBoundsError <: Exception

A `ParamBoundsError` is thrown upon an attempt to assign a parameter value that is not between `valuebounds`.
"""
type ParamBoundsError <: Exception
    msg::AbstractString
end
ParamBoundsError() = ParamBoundsError("Value not between valuebounds")
Base.showerror(io::IO, ex::ParamBoundsError) = print(io, ex.msg)

"""
parameter{T,U<:Transform}(key::Symbol, value::T, [valuebounds =
(value,value)], [transform_parameterization = (value,value)],
[transform = Untransformed()], [prior = NullablePrior()], [fixed =
true], [scaling::Function = identity], [description = ""],[texLabel::AbstractString = ""])


By default, returns a fixed `UnscaledParameter` object with key `key`
and value `value`. If `scaling` is given, a `ScaledParameter` object
is returned.

"""

function parameter{T,U<:Transform}(key::Symbol,
                                   value::T,
                                   valuebounds::Interval{T} = (value,value),
                                   transform_parameterization::Interval{T} = (value,value),
                                   transform::U             = Untransformed(),
                                   prior::NullableOrPrior   = NullablePrior();
                                   fixed::Bool              = true,
                                   scaling::Function        = identity,
                                   description::AbstractString = "",
                                   texLabel::AbstractString = "")

    
    # If fixed=true, force bounds to match and leave prior as null.  We need to define new
    # variable names here because of lexical scoping.

    ret_valuebounds = valuebounds
    ret_transform_parameterization = transform_parameterization
    ret_prior = prior

    if fixed
        ret_transform_parameterization = (value,value)  # value is transformed already       

        if isa(transform, Untransformed)
            ret_valuebounds = (value,value)
        end
    else
        ret_transform_parameterization = transform_parameterization
    end
    
    # ensure that we have a Nullable{Distribution}, if not construct one
    ret_prior = !isa(ret_prior,NullablePrior) ? NullablePrior(ret_prior) : ret_prior

    if scaling == identity
        return UnscaledParameter{T,U}(key, value, ret_valuebounds, ret_transform_parameterization, transform,
                                      ret_prior, fixed, description, texLabel)
    else
        return ScaledParameter{T,U}(key, value, scaling(value), ret_valuebounds, ret_transform_parameterization, transform,
                                    ret_prior, fixed, scaling, description, texLabel)
    end
end


"""
SteadyStateParameter{T<:Number}(key::Symbol, value::T;
[description::AbstractString = ""], [texLabel::AbstractString = ""])

SteadyStateParameter constructor with optional `description` and `texLabel` arguments.
"""
function SteadyStateParameter{T<:Number}(key::Symbol,
                                       value::T;
                                       description::AbstractString = "",
                                       texLabel::AbstractString = "")

    return SteadyStateParameter(key, value, description, texLabel)
end


"""
parameter{T<:Number,U<:Transform}(p::UnscaledParameter{T,U}, newvalue::T;
                                  [valuebounds::Interval{T} = p.valuebounds],
                                  [transform_parameterization::Interval{T} = p.transform_parameterization],
                                  [transform::Transform                    = p.transform],
                                  [prior::NullablePrior                    = p.prior],
                                  [fixed::Bool                             = p.fixed])
    

Returns an UnscaledParameter with value field equal to `newvalue`. Throws a
`ParamBoundsError` if `newvalue` is not between `valuebounds`.

If `fixed=true`, `p` will be returned unless the new
valuebounds and new prior (matching `newvalue`) are explicitly provided.
"""
function parameter{T<:Number,U<:Transform, V<:Transform}(p::UnscaledParameter{T,U}, newvalue::T;
                                           valuebounds::Interval{T}                = p.valuebounds,
                                           transform_parameterization::Interval{T} = p.transform_parameterization,
                                           transform::V                            = p.transform,
                                           prior::NullableOrPrior                  = p.prior,
                                           fixed::Bool                             = p.fixed)
    
    # don't change a fixed parameter unless both new valuebounds and prior are provided and match newvalue
    if fixed

        valuebounds != (newvalue,newvalue) && return p 
        
        if isa(prior, NullablePrior) && isa(prior.value, PointMass)
            !(prior.value.μ == newvalue) && return p
        elseif isa(prior, PointMass)
            !(prior.μ == newvalue) && return p
        else
            return p
        end
    end
    
    # make sure new value is between new bounds
    a,b = valuebounds  
    if !(a <= newvalue <= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end

    # ensure that we have a Nullable{Distribution}, if not construct one
    prior = !isa(prior,NullablePrior) ? NullablePrior(prior) : prior

    UnscaledParameter{T,V}(p.key, newvalue, valuebounds, transform_parameterization, transform, prior, fixed, p.description, p.texLabel)
end


"""
parameter{T<:Number,U<:Transform}(p::ScaledParameter{T,U}, newvalue::T;
                                  [valuebounds::Interval{T}                = p.valuebounds],
                                  [transform_parameterization::Interval{T} = p.transform_parameterization],
                                  [transform::Transform                    = p.transform],
                                  [prior::NullableOrPrior                  = p.prior],
                                  [fixed::Bool                             = p.fixed],
                                  [scaling::Function                       = p.scaling])


Returns a ScaledParameter with value field equal to `newvalue`,
scaledvalue field equal to `p.scaling(newvalue)`. Throws a `ParamBoundsError` if
`newvalue` is not between `valuebounds`.

If `fixed=true`, `p` will be returned unless the new
valuebounds and new prior (matching `newvalue`) are explicitly provided.
"""
function parameter{T<:Number,U<:Transform, V<:Transform}(p::ScaledParameter{T,U}, newvalue::T;
                                           valuebounds::Interval{T}                = p.valuebounds,
                                           transform_parameterization::Interval{T} = p.transform_parameterization,
                                           transform::V                            = p.transform,
                                           prior::NullableOrPrior                  = p.prior,
                                           fixed::Bool                             = p.fixed,
                                           scaling::Function                       = p.scaling)

    # don't change a fixed parameter unless both new valuebounds and prior are provided and match newvalue
    if fixed

        if valuebounds != (newvalue,newvalue)  return p end
        
        if isa(prior, NullablePrior) && isa(prior.value, PointMass)
            (prior.value.μ != newvalue) && return p
        elseif isa(prior, PointMass)
            (prior.μ != newvalue) && return p
        else
            return p
        end
    end
    
    # make sure new value is between new bounds
    a,b = valuebounds
    if !(a <= newvalue <= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end

    # ensure that we have a Nullable{Distribution}, if not construct one
    prior = !isa(prior,NullablePrior) ? NullablePrior(prior) : prior
    
    ScaledParameter{T,V}(p.key, newvalue, scaling(newvalue), valuebounds, transform_parameterization, transform, prior, fixed, scaling, p.description, p.texLabel)
end

function Base.show{T,U}(io::IO, p::Parameter{T,U})
    @printf io "%s\n" typeof(p)
    @printf io "(:%s)\n%s\n"      p.key p.description
    @printf io "LaTeX label: %s\n"     p.texLabel
    @printf io "-----------------------------\n"
    #@printf io "real value:        %+6f\n" toreal(p)
    @printf io "unscaled, untransformed value:        %+6f\n" p.value
    isa(p,ScaledParameter) && @printf "scaled, untransformed value:        %+6f\n" p.scaledvalue
    #!isa(U(),Untransformed) && @printf io "transformed value: %+6f\n" p.value
    
    if hasprior(p)
        @printf io "prior distribution:\n\t%s\n" get(p.prior)
    else
        @printf io "prior distribution:\n\t%s\n" "no prior"
    end

    @printf io "transformation for csminwel:\n\t%s" U()
    @printf io "parameter is %s\n" p.fixed ? "fixed" : "not fixed"
end

function Base.show{T}(io::IO, p::SteadyStateParameter{T})
    @printf io "%s\n" typeof(p)
    @printf io "(:%s)\n%s\n"      p.key p.description
    @printf io "LaTeX label: %s\n"     p.texLabel
    @printf io "-----------------------------\n"
    @printf io "value:        %+6f\n" p.value
end


"""
tomodel{T<:Number, U<:Transform}(p::Parameter{T,U}, x::T)

Transforms `x` from the real line to lie between `p.valuebounds` without updating
`p.value`. The transformations are defined as follows,
where (a,b) = p.transform_parameterization and c a scalar (default=1):

- Untransformed: x
- SquareRoot:    (a+b)/2 + (b-a)/2 * c * x/sqrt(1 + c^2 * x^2)
- Exponential:   a + exp(c*(x-b))
"""

"""
toreal{T<:Number, U<:Transform}(p::Parameter{T,U}, x::T = p.value)

Transforms `p.value` from model space (between `p.valuebounds`) to the real line, without updating
`p.value`. The transformations are defined as follows,
where (a,b) = p.transform_parameterization, c a scalar (default=1), and x = p.value:

- Untransformed: x
- SquareRoot:   (1/c)*cx/sqrt(1 - cx^2), where cx =  2 * (x - (a+b)/2)/(b-a)
- Exponential:   a + exp(c*(x-b))
"""
# Untransformed
tomodel{T}(p::Parameter{T,Untransformed}, x::T) = x
toreal{T}(p::Parameter{T,Untransformed}, x::T = p.value) = x

# SquareRoot
function tomodel{T}(p::Parameter{T,SquareRoot}, x::T)
    (a,b), c = p.transform_parameterization, one(T)
    (a+b)/2 + (b-a)/2*c*x/sqrt(1 + c^2 * x^2)
end
function toreal{T}(p::Parameter{T,SquareRoot}, x::T = p.value)
    (a,b), c = p.transform_parameterization, one(T)
    cx = 2 * (x - (a+b)/2)/(b-a)
    (1/c)*cx/sqrt(1 - cx^2)
end

# Exponential
function tomodel{T}(p::Parameter{T,Exponential}, x::T)
    (a,b),c = p.transform_parameterization,one(T)
    a + exp(c*(x-b))
end
function toreal{T}(p::Parameter{T,Exponential}, x::T = p.value)
    (a,b),c = p.transform_parameterization,one(T)
    b + (1/c) * log(x-a)
end

tomodel{T}(pvec::ParameterVector{T}) = map(tomodel, pvec)
toreal{T}(pvec::ParameterVector{T}, values::Vector{T}) = map(toreal, pvec, values)


# define operators to work on parameters

# TODO: do we also want to convert p to type AbstractParameter{T}? Seems so.
Base.convert{T<:Number}(::Type{T}, p::UnscaledParameter)  = convert(T,p.value)
Base.convert{T<:Number}(::Type{T}, p::ScaledParameter)    = convert(T,p.scaledvalue)  
Base.convert{T<:Number}(::Type{T}, p::SteadyStateParameter)  = convert(T,p.value)

Base.promote_rule{T<:Number,U<:Number}(::Type{AbstractParameter{T}}, ::Type{U}) = promote_rule(T,U)

for op in (:(Base.(:+)),
           :(Base.(:-)),
           :(Base.(:*)),
           :(Base.(:/)),
           :(Base.(:^)))

    @eval ($op)(p::UnscaledOrSteadyState, q::UnscaledOrSteadyState) = ($op)(p.value, q.value)
    @eval ($op)(p::UnscaledOrSteadyState, x::Integer)            = ($op)(p.value, x)
    @eval ($op)(p::UnscaledOrSteadyState, x::Number)            = ($op)(p.value, x)
    @eval ($op)(x::Number, p::UnscaledOrSteadyState)            = ($op)(x, p.value)

    @eval ($op)(p::ScaledParameter, q::ScaledParameter) = ($op)(p.scaledvalue, q.scaledvalue)
    @eval ($op)(p::ScaledParameter, x::Integer)            = ($op)(p.scaledvalue, x)
    @eval ($op)(p::ScaledParameter, x::Number)            = ($op)(p.scaledvalue, x)
    @eval ($op)(x::Number, p::ScaledParameter)            = ($op)(x, p.scaledvalue)

    @eval ($op)(p::ScaledParameter, q::UnscaledOrSteadyState) = ($op)(p.scaledvalue, q.value)
    @eval ($op)(p::UnscaledOrSteadyState, q::ScaledParameter) = ($op)(p.value, q.scaledvalue)
end

for f in (:(Base.exp),
          :(Base.log),
          :(Base.(:-)),
          :(Base.(:<)),
          :(Base.(:>)),
          :(Base.(:<=)),
          :(Base.(:>=)))

    @eval ($f)(p::UnscaledOrSteadyState) = ($f)(p.value)
    @eval ($f)(p::ScaledParameter) = ($f)(p.scaledvalue)
end

"""
update!{T}(pvec::ParameterVector{T}, newvalues::Vector{T})

Update all parameters in `pvec` that are not fixed with
`newvalues`. Length of `newvalues` must equal length of `pvec`.
"""
# this function is optimised for speed
function update!{T}(pvec::ParameterVector{T}, newvalues::Vector{T})
    @assert length(newvalues) == length(pvec) "Length of input vector (=$(length(newvalues))) must match length of parameter vector (=$(length(pvec)))"
    map!(parameter, pvec, pvec, newvalues)
end

"""
update{T}(pvec::ParameterVector{T}, newvalues::Vector{T})

Returns a copy of `pvec` where non-fixed parameter values are udpated
to `newvalues`. `pvec` remains unchanged. Length of `newvalues` must
equal length of `pvec`.
"""
# define the non-mutating version like this because we need the type stability of map!
update{T}(pvec::ParameterVector{T}, newvalues::Vector{T}) = update!(copy(pvec), newvalues)

Distributions.pdf(p::AbstractParameter) = exp(logpdf(p))
Distributions.logpdf{T,U}(p::Parameter{T,U}) = logpdf(get(p.prior),p.value) # we want the unscaled value for ScaledParameters


# this function is optimised for speed
function Distributions.logpdf{T}(pvec::ParameterVector{T})
	x = zero(T)
	@inbounds for i = 1:length(pvec)
        if hasprior(pvec[i])
    		x += logpdf(pvec[i])
        end
	end
	x
end

# calculate logpdf at new values, without needing to allocate a temporary array with update
function Distributions.logpdf{T}(pvec::ParameterVector{T}, newvalues::Vector{T})
    @assert length(newvalues) == length(pvec) "Length of input vector (=$(length(newvalues))) must match length of parameter vector (=$(length(pvec)))"
    
    x = zero(T)
    @inbounds for i = 1:length(pvec)
        if hasprior(pvec[i])
            x += logpdf(parameter(pvec[i], newvalues[i]))
        end
    end
    x
end

Distributions.pdf{T}(pvec::ParameterVector{T}) = exp(logpdf(pvec))
Distributions.pdf{T}(pvec::ParameterVector{T}, newvalues::Vector{T}) = exp(logpdf(pvec, newvalues))
