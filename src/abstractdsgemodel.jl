abstract AbstractDSGEModel{T<:AbstractFloat}

function Base.show{T<:AbstractDSGEModel}(io::IO, m::T)
    @printf io "Dynamic Stochastic General Equilibrium Model\n"
    @printf io "%s\n" T
    @printf io "no. states:             %i\n" num_states(m)
    @printf io "no. anticipated shocks: %i\n" num_anticipated_shocks(m)
    @printf io "no. anticipated lags:   %i\n" num_anticipated_lags(m)
    @printf io "description:\n %s\n"          description(m)
end

@inline function Base.getindex(m::AbstractDSGEModel, i::Integer)
    if i <= (j = length(m.parameters))
        return m.parameters[i]
    else
        return m.steady_state[i-j]
    end
end

# need to define like this so we can disable bounds checking
@inline function Base.getindex(m::AbstractDSGEModel, k::Symbol)
    i = m.keys[k]
    @inbounds if i <= (j = length(m.parameters))
        return m.parameters[i]
    else
        return m.steady_state[i-j]
    end
end

@inline function Base.setindex!(m::AbstractDSGEModel, value, i::Integer)
    if i <= (j = length(m.parameters))
        param = m.parameters[i]
        param.value = value
        if isa(ScaledParameter)
            param.scaledvalue = param.scaling(value)
        end
        return param
    else
        ssparam = m.steady_state[i-j]
        ssparam.value = value
        return ssparam
    end
end
Base.setindex!(m::AbstractDSGEModel, value, k::Symbol) = Base.setindex!(m, value, m.keys[k])

#=
"""
(<=){T}(m::AbstractDSGEModel{T}, p::AbstractParameter{T})

Syntax for adding a parameter to a model: m <= parameter.
NOTE: If `p` is added to `m` and length(m.steady_state) > 0, `keys(m)` will not generate the index of `p` in `m.parameters`.
"""
=#
function (<=){T}(m::AbstractDSGEModel{T}, p::AbstractParameter{T})
    @assert !in(p.key, keys(m.keys)) "Key $(p.key) is already present in DSGE model"

    new_param_index = length(m.keys) + 1

    # grow parameters and add the parameter
    push!(m.parameters, p)

    # add parameter location to dict
    setindex!(m.keys, new_param_index, p.key)
end

#=
"""
(<=){T}(m::AbstractDSGEModel{T}, ssp::SteadyStateParameter)

Add a new steady-state value to the model by appending `ssp` to the `m.steady_state` and adding `ssp.key` to `m.keys`.
"""
=#
function (<=){T}(m::AbstractDSGEModel{T}, ssp::SteadyStateParameter)
    @assert !in(ssp.key, keys(m.keys)) "Key $(ssp) is already present in DSGE model"

    new_param_index = length(m.keys) + 1

    # append ssp to steady_state vector
    push!(m.steady_state, ssp)

    # add parameter location to dict
    setindex!(m.keys, new_param_index, ssp.key)
end

## Defunct bc steady state values have their own type now
## #=
## """
## (<=)(m::AbstractDSGEModel, vec::Vector{Symbol})

## Add all elements of `vec` to the `m.steady_state`. Update `m.keys` appropriately.
## """
## =#

## function (<=)(m::AbstractDSGEModel, vec::Vector{Symbol})
##     for k in vec
##         m <= k
##     end
## end

Distributions.logpdf(m::AbstractDSGEModel) = logpdf(m.parameters)
Distributions.pdf(m::AbstractDSGEModel) = exp(logpdf(m))

# Number of anticipated policy shocks
num_anticipated_shocks(m::AbstractDSGEModel) = m.num_anticipated_shocks

# Padding for number of anticipated policy shocks
num_anticipated_shocks_padding(m::AbstractDSGEModel) = m.num_anticipated_shocks_padding

# Number of periods back we should start incorporating zero bound expectations
# ZLB expectations should begin in 2008 Q4
num_anticipated_lags(m::AbstractDSGEModel) = m.num_anticipated_lags

# TODO: This should be set when the data are read in
# Number of presample periods
num_presample_periods(m::AbstractDSGEModel) = m.num_presample_periods

# Number of a few things that are useful apparently
num_states(m::AbstractDSGEModel)                 = length(m.endogenous_states)
num_states_augmented(m::AbstractDSGEModel)       = num_states(m) + length(m.endogenous_states_postgensys)
num_shocks_exogenous(m::AbstractDSGEModel)       = length(m.exogenous_shocks)
num_shocks_expectational(m::AbstractDSGEModel)   = length(m.expected_shocks)
num_equilibrium_conditions(m::AbstractDSGEModel) = length(m.equilibrium_conditions)
num_observables(m::AbstractDSGEModel)            = length(m.observables)
num_parameters(m::AbstractDSGEModel)             = length(m.parameters)
num_parameters_fixed(m::AbstractDSGEModel)       = length(m.parameters_fixed)
num_parameters_steady_state(m::AbstractDSGEModel)= length(m.steady_state)
num_parameters_free(m::AbstractDSGEModel)        = sum([!α.fixed for α in m.parameters])


# Paths to where input/output/results data are stored
savepath(m::AbstractDSGEModel)  = m.savepaths[:savepath]
inpath(m::AbstractDSGEModel)    = m.savepaths[:inpath]
outpath(m::AbstractDSGEModel)   = m.savepaths[:outpath]
tablepath(m::AbstractDSGEModel) = m.savepaths[:tablepath]
plotpath(m::AbstractDSGEModel)  = m.savepaths[:plotpath]
logpath(m::AbstractDSGEModel)   = m.savepaths[:logpath]


#=
doc"""
create_save_directories{T<:AbstractString}(m::AbstractDSGEModel, savepath::T; reset_inpath::Bool=true)

### Parameters
- `m`: the model object
- `savepath`: the desired root of the new save subtree

### Optional Arguments
- `reset_inpath`: Whether to set the value of `m.savepaths[:inpath]` to `new_savepath/input_data`. Default = `true`.

### Description
Creates the default directory structure for input and output files rooted at `savepath` and updates `m.savepaths` appropriately. By default, resets m`.savepaths[:inpath]` to `new_savepath/input_data`.
"""
=#
function create_save_directories{T<:AbstractString}(m::AbstractDSGEModel, savepath::T; reset_inpath::Bool=true)

    create_save_directories(savepath)

    paths = [(:savepath,  savepath),
             (:outpath,   joinpath(savepath, "output_data")),
             (:logpath,   joinpath(savepath, "logs")),
             (:tablepath, joinpath(savepath, "results/tables")),
             (:plotpath,  joinpath(savepath, "results/plots"))]

    if reset_inpath
        append!(paths, [(:inpath, joinpath(savepath, "input_data"))])
    else
        append!(paths, [(:inpath, inpath(m))])
    end

    m.savepaths = Dict{Symbol,AbstractString}(paths)
    
end

#=
doc"""
create_save_directories{T<:AbstractString}(m::AbstractDSGEModel, new_savepath::T, old_savepath::T; reset_inpath::Bool=true, copy_infiles::Bool=true)

### Parameters
- `m`: the model object
- `new_savepath`: the desired root of the new save subtree
- `old_savepath`: the root of the old save directory subtree. 

### Optional Arguments
- `reset_inpath`: Whether to set the value of `m.savepaths[:inpath]` to `new_savepath/input_data`. Default = `true`.
- `copy_infiles`: Whether to copy the input files 

### Description
Creates the default directory structure for input and output files rooted at `new_savepath` by calling `create_save_directories(m, new_savepath; reset_inpath=reset_inpath)`. By default, resets m`.savepaths[:inpath]` to `new_savepath/input_data` and copies input files from `old_savepath` to that directory.


### Usage
This method is intended to be used after a model object is created with the default savepath location, in the event that the user decides to use the same directory structure rooted elsewhere in the filesystem. It allows the user to run multiple versions of the model with the same input files (without making a copy). In this case, the `reset_inpath` and `copy_infiles` arguments should be set to `false`.

`new_savepath` and `old_savepath` refer to the directory that will contain (in the case of `new_savepath`) or contains (in the case of `old_savepath`) the `input_data`, `output_data`, `results`, and `log` subdirectories. 
"""
=#
function create_save_directories{T<:AbstractString}(m::AbstractDSGEModel, new_savepath::T, old_savepath::T; reset_inpath::Bool=true, copy_infiles::Bool=true)

    create_save_directories(m, new_savepath; reset_inpath=reset_inpath)

    if copy_infiles
        for file in readdir(normpath(joinpath(old_savepath, "input_data")))
            println(file)
            cp(abspath(joinpath(old_savepath, "input_data/$file")), inpath(m))
            old = abspath(joinpath(old_savepath, "input_data/$file"))
            new = abspath(joinpath(new_savepath, "input_data"))
            @printf "Copied %s to %s" old new
        end
    end

    return m.savepaths
end



# TODO is there a better place for these? They do depend on AbstractDSGEModel type.
#=
doc"""
tomodel!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})

### Parameters:
-`m`: the model object
-`values`: the new values to assign to non-steady-state parameters.

### Description:
Transforms `values` from the real line to the model space, and assigns `values[i]` to `m.parameters[i].value` for non-steady-state parameters. Recomputes the steady-state paramter values.
"""
=#
function tomodel!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})
    tomodel!(values, m.parameters)
    return steadystate!(m)
end

#=
doc"""
update!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})

### Parameters:
-`m`: the model object
-`values`: the new values to assign to non-steady-state parameters.

### Description:
Update `m.parameters` with `values`, recomputing the steady-state parameter values.
"""
=#
function update!{T<:AbstractFloat}(m::AbstractDSGEModel, values::Vector{T})
    update!(m.parameters, values)
    return steadystate!(m) 
end

#=
doc"""
Distributions.rand{T<:AbstractFloat, U<:AbstractDSGEModel}(d::DegenerateMvNormal, m::U; cc::T = 1.0)

Generate a draw from d with variance optionally scaled by cc^2.
"""
=#
@debug function rand{T<:AbstractFloat, U<:AbstractDSGEModel}(d::DegenerateMvNormal, m::U; cc::T = 1.0)
    return d.μ + cc*d.σ*randn(m.rng, length(d))
end
