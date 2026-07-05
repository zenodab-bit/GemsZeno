@with_kw struct EventSection
    id::String
    n::Int                        # precise mode
    age_dist::Vector{Float64}
    sex_dist::Vector{Vector{Float64}}
    mean_event_contacts::Float64
    # category mode
    n_range::Tuple{Int,Int}       # sample size from this range
end

@with_kw struct Event
    id::Int
    date::Int                     # precise mode
    sections::Vector{EventSection}
    # category mode
    date_range::Tuple{Int,Int}
    n_draws::Int                  # how many events to sample from this category
end


@with_kw struct EventConfig
    events::Vector{Event}
    mode::Symbol                  # :precise or :category
    transmission_rate::Float64
    age_boundaries::Vector{Int}   # e.g. [45, 65]
end

@kwdef mutable struct EventAttendance
    event_id::Vector{Int32} = Int32[]
    section_id::Vector{Int32} = Int32[]
    mean_event_contacts::Vector{Float64} = Float64[]
    event_date::Vector{Int32} = Int32[]
end


# Define sections for event 1
section_1_1 = EventSection( 
    id = "1_1",
    n = 500,
    age_dist = [0.211, 0.347, 0.442],
    sex_dist = [[0.420, 0.580], [0.395, 0.605], [0.426, 0.574]],
    mean_event_contacts = 4.0,
    n_range = (0, 0)  # unused in precise mode
)

section_1_2 = EventSection(
    id = "1_2",
    n = 500,
    age_dist = [0.211, 0.347, 0.442],
    sex_dist = [[0.420, 0.580], [0.395, 0.605], [0.426, 0.574]],
    mean_event_contacts = 12.0,
    n_range = (0, 0)
)

# Define event 1
event_1 = Event(
    id = 1,
    date = 10,
    sections = [section_1_1, section_1_2],
    date_range = (0, 0),  # unused in precise mode
    n_draws = 0            # unused in precise mode
)

# Full config
event_config = EventConfig(
    events = [event_1],
    mode = :precise,
    transmission_rate = 0.3,
    age_boundaries = [45, 65]
)