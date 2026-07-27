using Parameters

function negbin_params(mean, std)
    variance = std^2
    p = mean / variance
    r = mean^2 / (variance - mean)
    return r, p
end

function gamma_params(mean, std)
    variance = std^2
    β = variance / mean
    α = mean / β
    return α, β
end

## === Structs ===

@with_kw struct Section
    id::Int
    name::String = ""
    n_range::Tuple{Int,Int}
    mean_contacts::Float64
    std_contacts::Float64 = 0.0
end

@with_kw struct Category
    id::Int
    name::String = ""
    date_range::Tuple{Int,Int}
    sections::Vector{Section}
    n_draws::Int
    min_age::Int = 0
    max_age::Int = 999
    age_weights::Vector{Float64} = Float64[]
    sex_weights::Vector{Float64} = Float64[]
    core::Float64 = 0.0
    loyalty::Float64 = 0.0
    min_superspreaders::Int = 0
end

@with_kw struct EventConfig
    categories::Vector{Category}
    transmission_rate::Float64
    age_boundaries::Vector{Int}
    age_dist::Vector{Float64}
    sex_dist::Vector{Vector{Float64}}
end

# Runtime struct — produced by sample_events, not defined by user
@with_kw struct Event
    id::String
    name::String
    category_id::Int
    draw_id::Int
    section_id::Int
    date::Int
    n::Int
    mean_contacts::Float64
    std_contacts::Float64
end