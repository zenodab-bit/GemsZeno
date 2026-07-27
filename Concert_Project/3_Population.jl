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
        used_dates = Set{Int}()  # track dates used by this category

        for draw in 1:category.n_draws
            # sample date excluding already used ones
            available_dates = setdiff(category.date_range[1]:category.date_range[2], used_dates)

            if isempty(available_dates)
                @warn "Category $(category.name): not enough unique dates for $(category.n_draws) draws in range $(category.date_range)."
                date = rand(rng, category.date_range[1]:category.date_range[2])
            else
                date = rand(rng, collect(available_dates))
            end
            push!(used_dates, date)

            for section in category.sections
                n = rand(rng, section.n_range[1]:section.n_range[2])
                id = "$(category.id)_$(draw)_$(section.id)"

                parts = String[]
                if !isempty(category.name)
                    push!(parts, category.name)
                end
                if category.n_draws > 1
                    push!(parts, "draw$(draw)")
                end
                if length(category.sections) > 1
                    if !isempty(section.name)
                        push!(parts, section.name)
                    else
                        push!(parts, "sec$(section.id)")
                    end
                end
                name = isempty(parts) ? id : join(parts, "_")

                push!(events, Event(
                    id=id,
                    name=name,
                    category_id=category.id,
                    draw_id=draw,
                    section_id=section.id,
                    date=date,
                    n=n,
                    mean_contacts=section.mean_contacts,
                    std_contacts=section.std_contacts
                ))
            end
        end
    end

    return events
end


## === Prepare Population ===

function prepare_population(event_config::EventConfig, rng)
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
    people.std_event_contacts = [Float64[] for _ in 1:nrow(people)]

    α_normal, β_normal = gamma_params(general_rate, std_rate)
    α_super, β_super = gamma_params(superspreader_rate, superspreader_std)

    people.is_superspreader = [rand(rng) < superspreader_prob for _ in 1:nrow(people)]
    people.transmission_prob = Float64[
        people.is_superspreader[i] ?
        rand(rng, Gamma(α_super, β_super)) :
        rand(rng, Gamma(α_normal, β_normal))
        for i in 1:nrow(people)
    ]

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
    loyal_pools = Dict{Int,Dict{Int,Int}}()
    core_groups = Dict{Int,Vector{Int}}()
    all_core_members = Set{Int}()

    for category in event_config.categories
        first_event_idx = findfirst(e -> e.category_id == category.id, events)
        first_event_idx === nothing && continue
        first_n = events[first_event_idx].n

        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )

        n_core_total = round(Int, first_n * category.core)
        core_groups[category.id] = Int[]

        # 1. superspreader core
        if category.min_superspreaders > 0
            available_supers = filter(idx ->
                    people.is_superspreader[idx] &&
                    idx ∉ all_core_members,
                base_candidates)
            n_super_core = min(category.min_superspreaders, length(available_supers))
            if n_super_core < category.min_superspreaders
                @warn "Category $(category.name): requested $(category.min_superspreaders) superspreader(s) in core but only $n_super_core available."
            end
            if n_super_core > 0
                super_core = sample(rng, available_supers, n_super_core, replace=false)
                append!(core_groups[category.id], super_core)
            end
        end

        # 2. regular core
        n_regular_core = max(0, n_core_total - length(core_groups[category.id]))
        if n_regular_core > 0
            remaining_for_core = filter(idx ->
                    idx ∉ core_groups[category.id] &&
                    idx ∉ all_core_members,
                base_candidates)
            core_weights = compute_weights(people, remaining_for_core, category, event_config)
            n_to_sample = min(n_regular_core, length(remaining_for_core))
            regular_core = sample(rng, remaining_for_core, Weights(core_weights), n_to_sample, replace=false)
            append!(core_groups[category.id], regular_core)
        end

        union!(all_core_members, core_groups[category.id])
    end

    for event in events
        category = event_config.categories[findfirst(c -> c.id == event.category_id, event_config.categories)]

        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )

        selected = Int[]

        # 1. add core group (filter same-day conflicts)
        if haskey(core_groups, category.id)
            available_core = filter(idx ->
                    !any(people.event_dates[idx] .== event.date),
                core_groups[category.id])
            append!(selected, available_core)
        end

        # 2. random pool with unified loyalty weights
        n_remaining = event.n - length(selected)
        remaining = filter(idx ->
                idx ∉ selected &&
                !any(people.event_dates[idx] .== event.date),
            base_candidates)

        remaining_weights = compute_weights(people, remaining, category, event_config)

        # apply loyalty weights
        if category.loyalty != 0.0 && haskey(loyal_pools, category.id)
            pool = loyal_pools[category.id]
            for (i, idx) in enumerate(remaining)
                n_prev = get(pool, idx, 0)
                if n_prev > 0
                    remaining_weights[i] *= (1 + category.loyalty)^n_prev
                end
            end
            total = sum(remaining_weights)
            remaining_weights = total > 0 ? remaining_weights ./ total : ones(length(remaining_weights)) ./ length(remaining_weights)
        end

        n_to_sample = min(n_remaining, length(remaining))
        if n_to_sample > 0
            new_selected = sample(rng, remaining, Weights(remaining_weights), n_to_sample, replace=false)
            append!(selected, new_selected)
        end

        # update loyal pool
        if !haskey(loyal_pools, category.id)
            loyal_pools[category.id] = Dict{Int,Int}()
        end
        for idx in selected
            loyal_pools[category.id][idx] = get(loyal_pools[category.id], idx, 0) + 1
        end

        # assign to people
        for idx in selected
            push!(people.category_ids[idx], Int32(event.category_id))
            push!(people.event_ids[idx], Int32(event.draw_id))
            push!(people.section_ids[idx], Int32(event.section_id))
            push!(people.mean_event_contacts[idx], event.mean_contacts)
            push!(people.std_event_contacts[idx], event.std_contacts)
            push!(people.event_dates[idx], Int32(event.date))
        end
    end
end

## Superspreaders

