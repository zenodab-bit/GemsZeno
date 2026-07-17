using Parameters

## === Structs ===

@with_kw struct Section
    id::Int
    n_range::Tuple{Int,Int}
    mean_contacts::Float64
end

@with_kw struct Category
    id::Int
    date_range::Tuple{Int,Int}
    sections::Vector{Section}
    n_draws::Int
    min_age::Int = 0
    max_age::Int = 999
    age_weights::Vector{Float64} = Float64[]
    sex_weights::Vector{Float64} = Float64[]
    core::Float64 = 0.0      # fraction always attending
    loyalty::Float64 = 0.0   # fraction repeating from pool
end

@with_kw struct EventConfig
    categories::Vector{Category}
    transmission_rate::Float64
    age_boundaries::Vector{Int}
    age_dist::Vector{Float64}             # overall population age distribution
    sex_dist::Vector{Vector{Float64}}     # overall population sex distribution per age group
end

# Runtime struct — produced by sample_events, not defined by user
@with_kw struct Event
    id::String
    category_id::Int
    draw_id::Int
    section_id::Int
    date::Int
    n::Int
    mean_contacts::Float64
end

function gamma_params(mean, std)
    variance = std^2
    β = variance / mean
    α = mean / β
    return α, β
end

# normal spreaders: mean transmission prob = 0.3, low variance
α_normal, β_normal = gamma_params(0.3, 0.1)

# superspreaders: mean transmission prob = 0.9, higher variance  
α_super, β_super = gamma_params(0.3, 0.1)

superspreader_prob = 0.10  # 10% of population

## === Event Definitions ===

# Category 1: festival with seated and standing — fixed day 40
category_1 = Category(
    id = 1,
    date_range = (40, 40),
    sections = [
        Section(id=1, n_range=(50,50), mean_contacts=4.0),
        Section(id=2, n_range=(50,50), mean_contacts=12.0)
    ],
    n_draws = 1,
    min_age = 18,
    max_age = 999,
    age_weights = [0.5, 0.35, 0.15],
    sex_weights = [0.6, 0.4],
    loyalty = 0.0
)

# Category 2: small concerts — random dates, high loyalty
category_2 = Category(
    id = 2,
    date_range = (10, 40),
    sections = [
        Section(id=1, n_range=(20,40), mean_contacts=8.0)
    ],
    n_draws = 5,
    min_age = 16,
    max_age = 999,
    age_weights = [0.45, 0.40, 0.15],
    sex_weights = [0.55, 0.45],
    core = 0.3,
    loyalty = -0.5
)

event_config = EventConfig(
    categories = [category_2],
    transmission_rate = 0.3,
    age_boundaries = [45, 65],
    age_dist = [0.211, 0.347, 0.442],
    sex_dist = [[0.420, 0.580], [0.395, 0.605], [0.426, 0.574]]
)