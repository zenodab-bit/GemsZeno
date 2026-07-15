## === Helper functions ===

function age_group_label(age, age_boundaries)
    for i in eachindex(age_boundaries)
        if age <= age_boundaries[i]
            return "<=$(age_boundaries[i])"
        end
    end
    return ">$(age_boundaries[end])"
end

function age_group_idx(age, age_boundaries)
    for (i, boundary) in enumerate(age_boundaries)
        if age <= boundary
            return i
        end
    end
    return length(age_boundaries) + 1
end


## === Sample Events ===

function sample_events(event_config::EventConfig, rng)
    events = Vector{Event}()

    for category in event_config.categories
        for draw in 1:category.n_draws
            date = rand(rng, category.date_range[1]:category.date_range[2])

            for section in category.sections
                n = rand(rng, section.n_range[1]:section.n_range[2])
                id = "$(category.id)_$(draw)_$(section.id)"

                push!(events, Event(
                    id            = id,
                    category_id   = category.id,
                    draw_id       = draw,
                    section_id    = section.id,
                    date          = date,
                    n             = n,
                    mean_contacts = section.mean_contacts
                ))
            end
        end
    end

    return events
end


## === Prepare Population ===

function prepare_population(event_config::EventConfig)
    people = JLD2.load(joinpath(@__DIR__, "Datastorage", "people_Saalekreis.jld2"))["data"]

    age_boundaries = event_config.age_boundaries
    age_groups = [i == length(age_boundaries) + 1 ?
                  ">$(age_boundaries[end])" :
                  "<=$(age_boundaries[i])"
                  for i in 1:length(age_boundaries)+1]
    sex_levels = [1, 2]

    people.age_group = age_group_label.(people.age, Ref(age_boundaries))
    people.age_group = categorical(people.age_group; ordered=true, levels=age_groups)

    people.event_ids           = [Int32[] for _ in 1:nrow(people)]
    people.section_ids         = [Int32[] for _ in 1:nrow(people)]
    people.mean_event_contacts = [Float64[] for _ in 1:nrow(people)]
    people.event_dates         = [Int32[] for _ in 1:nrow(people)]

    return people, age_groups, sex_levels
end


## === Compute Weights ===

function compute_weights(people, candidates, category, event_config)
    age_boundaries = event_config.age_boundaries

    weights = Float64[]
    for idx in candidates
        age = people.age[idx]
        sex = people.sex[idx]

        age_idx = age_group_idx(age, age_boundaries)

        # age weight
        aw = isempty(category.age_weights) ?
             event_config.age_dist[age_idx] :
             category.age_weights[age_idx]

        # sex weight
        sw = isempty(category.sex_weights) ?
             event_config.sex_dist[age_idx][sex] :
             category.sex_weights[sex]

        push!(weights, aw * sw)
    end

    # normalize
    total = sum(weights)
    return total > 0 ? weights ./ total : ones(length(weights)) ./ length(weights)
end


## === Assign Events ===

function assign_events!(people::DataFrame, events::Vector{Event}, event_config::EventConfig, rng)
    loyal_pools = Dict{Int, Vector{Int}}()  # category_id => person indices

    for event in events
        category = event_config.categories[findfirst(c -> c.id == event.category_id, 
                                                      event_config.categories)]

        # hard age filter
        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )


        # split between loyal and new
        n_loyal = round(Int, event.n * category.loyalty)
        n_new   = event.n - n_loyal

        selected = Int[]

        # loyal attendees from existing pool
        if n_loyal > 0 && haskey(loyal_pools, category.id)
            pool = loyal_pools[category.id]
            n_from_pool = min(n_loyal, length(pool))
            append!(selected, sample(rng, pool, n_from_pool, replace=false))
        end

        # new attendees — weighted, excluding already selected
        remaining = setdiff(base_candidates, selected)
        remaining_weights = compute_weights(people, remaining, category, event_config)
        n_to_sample = min(n_new + (n_loyal - length(selected)), length(remaining))

        if n_to_sample > 0
            new_selected = sample(rng, remaining, Weights(remaining_weights), 
                                  n_to_sample, replace=false)
            append!(selected, new_selected)
        end

        # update loyal pool
        if !haskey(loyal_pools, category.id)
            loyal_pools[category.id] = Int[]
        end
        for idx in selected
            idx ∉ loyal_pools[category.id] && push!(loyal_pools[category.id], idx)
        end

        # assign to people
        for idx in selected
            push!(people.event_ids[idx],           Int32(event.category_id))
            push!(people.section_ids[idx],         Int32(event.section_id))
            push!(people.mean_event_contacts[idx], event.mean_contacts)
            push!(people.event_dates[idx],         Int32(event.date))
        end
    end
end
