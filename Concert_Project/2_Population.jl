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
                    id=id,
                    category_id=category.id,
                    draw_id=draw,
                    section_id=section.id,
                    date=date,
                    n=n,
                    mean_contacts=section.mean_contacts
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
                  for i in 1:(length(age_boundaries)+1)]
    sex_levels = [1, 2]

    people.age_group = age_group_label.(people.age, Ref(age_boundaries))
    people.age_group = categorical(people.age_group; ordered=true, levels=age_groups)

    people.category_ids = [Int32[] for _ in 1:nrow(people)]
    people.event_ids = [Int32[] for _ in 1:nrow(people)]
    people.section_ids = [Int32[] for _ in 1:nrow(people)]
    people.mean_event_contacts = [Float64[] for _ in 1:nrow(people)]
    people.event_dates = [Int32[] for _ in 1:nrow(people)]
    people.attendance_counts = [Dict{Int32,Int32}() for _ in 1:nrow(people)]

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
    loyal_pools = Dict{Int,Vector{Int}}()
    core_groups = Dict{Int,Vector{Int}}()

    # pre-select core groups for each category
    for category in event_config.categories
        category.core == 0.0 && continue

        # find first event of this category to determine core size
        first_event = findfirst(e -> e.category_id == category.id, events)
        first_event === nothing && continue
        n_core = round(Int, events[first_event].n * category.core)
        n_core == 0 && continue

        # eligible candidates
        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )

        weights = compute_weights(people, base_candidates, category, event_config)
        core_groups[category.id] = sample(rng, base_candidates, Weights(weights), n_core, replace=false)
    end

    for event in events
        category = event_config.categories[findfirst(c -> c.id == event.category_id, event_config.categories)]

        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )

        selected = Int[]

        # 1. add core group (always attend, filter out same-day conflicts)
        if haskey(core_groups, category.id)
            available_core = filter(idx ->
                    !any(people.event_dates[idx] .== event.date),
                core_groups[category.id])
            append!(selected, available_core)
        end

        n_core_selected = length(selected)
        n_remaining = event.n - n_core_selected

        # 2. loyal attendees from pool
        # 2. loyal attendees from pool
        n_loyal = category.loyalty > 0 ? round(Int, n_remaining * category.loyalty) : 0
        if n_loyal > 0 && haskey(loyal_pools, category.id)
            pool = loyal_pools[category.id]
            available_pool = filter(idx ->
                    idx ∉ selected &&
                    !any(people.event_dates[idx] .== event.date),
                pool)
            n_from_pool = min(n_loyal, length(available_pool))
            append!(selected, sample(rng, available_pool, n_from_pool, replace=false))
        end

        # 3. new random attendees
        n_new = event.n - length(selected)

        if category.loyalty < 0 && haskey(loyal_pools, category.id)
            pool = loyal_pools[category.id]
            n_to_exclude = round(Int, abs(category.loyalty) * length(pool))
            excluded = Set(sample(rng, pool, min(n_to_exclude, length(pool)), replace=false))
            remaining = filter(idx ->
                    idx ∉ selected &&
                    idx ∉ excluded &&
                    !any(people.event_dates[idx] .== event.date),
                base_candidates)
        else
            remaining = filter(idx ->
                    idx ∉ selected &&
                    !any(people.event_dates[idx] .== event.date),
                base_candidates)
        end
        remaining_weights = compute_weights(people, remaining, category, event_config)
        # adjust weights based on loyalty and attendance history
        if category.loyalty != 0.0
            for (i, idx) in enumerate(remaining)
                n_prev = get(people.attendance_counts[idx], Int32(category.id), 0)
                if n_prev > 0
                    remaining_weights[i] *= (1 + category.loyalty)^n_prev
                end
            end
            total = sum(remaining_weights)
            remaining_weights = total > 0 ? remaining_weights ./ total : ones(length(remaining_weights)) ./ length(remaining_weights)
        end
        n_to_sample = min(n_new, length(remaining))

        if n_to_sample > 0
            new_selected = sample(rng, remaining, Weights(remaining_weights), n_to_sample, replace=false)
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
            push!(people.category_ids[idx], Int32(event.category_id))
            push!(people.event_ids[idx], Int32(event.draw_id))
            push!(people.section_ids[idx], Int32(event.section_id))
            push!(people.mean_event_contacts[idx], event.mean_contacts)
            push!(people.event_dates[idx], Int32(event.date))
        end
        # increment attendance count for this category
        for idx in selected
            cat_id = Int32(event.category_id)
            people.attendance_counts[idx][cat_id] = get(people.attendance_counts[idx], cat_id, 0) + 1
        end
    end
end

## Superspreaders

people.transmission_multiplier = [
    rand(rng) < superspreader_prob ? 
    rand(rng, Gamma(α_super, β_super)) :  # superspreader distribution
    rand(rng, Gamma(α_normal, β_normal))   # normal distribution
    for _ in 1:nrow(people)
]