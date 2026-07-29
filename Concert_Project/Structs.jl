function negbin_params(mean, std)
    variance = std^2
    p = mean / variance
    r = mean^2 / (variance - mean)
    return r, p
end

function sample_n_contacts(rng, mean, std)
    mean <= 0 && return 0
    variance = std^2
    if variance <= mean
        # NegBin requires variance > mean; fall back to Poisson (variance == mean)
        return rand(rng, Poisson(mean))
    end
    r, p = negbin_params(mean, std)
    return rand(rng, NegativeBinomial(r, p))
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

function validate_config(event_config::EventConfig)
    n_groups = length(event_config.age_boundaries) + 1

    length(event_config.age_dist) == n_groups ||
        error("age_dist has $(length(event_config.age_dist)) entries, expected $n_groups (length(age_boundaries)+1).")

    isapprox(sum(event_config.age_dist), 1.0; atol=1e-6) ||
        @warn "age_dist sums to $(sum(event_config.age_dist)), not 1.0 — event demographics will be silently skewed."

    length(event_config.sex_dist) == n_groups ||
        error("sex_dist has $(length(event_config.sex_dist)) entries, expected $n_groups (one per age group).")

    for (i, sd) in enumerate(event_config.sex_dist)
        length(sd) == 2 || error("sex_dist[$i] has $(length(sd)) entries, expected 2.")
    end

    for category in event_config.categories
        if !isempty(category.age_weights)
            length(category.age_weights) == n_groups ||
                error("Category $(category.name): age_weights has $(length(category.age_weights)) entries, expected $n_groups.")
        end
        if !isempty(category.sex_weights)
            length(category.sex_weights) == 2 ||
                error("Category $(category.name): sex_weights has $(length(category.sex_weights)) entries, expected 2.")
        end
        category.min_age <= category.max_age ||
            error("Category $(category.name): min_age ($(category.min_age)) exceeds max_age ($(category.max_age)).")
        category.date_range[1] <= category.date_range[2] ||
            error("Category $(category.name): date_range $(category.date_range) is invalid (start > end).")
        for section in category.sections
            section.n_range[1] <= section.n_range[2] ||
                error("Category $(category.name), section $(section.id): n_range $(section.n_range) is invalid (start > end).")
        end
        0.0 <= category.core <= 1.0 ||
            error("Category $(category.name): core ($(category.core)) must be between 0 and 1.")

    end

    println("Config validated OK.")
end

println("End Structs")