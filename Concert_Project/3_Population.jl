# ===========================================================================
# 3_Population.jl
#
# Turns an EventConfig into concrete events and a simulation-ready
# population, and assigns people to those events. Three pieces, used
# together by 2_Interface.jl in this order:
#   1. sample_events(event_config, rng)       - returns Vector{Event}
#   2. prepare_population(event_config, rng)  - returns people DataFrame + labels
#   3. assign_events!(people, events, ...)    - returns attendees Dict,
#                                                mutates `people` in place

# ===========================================================================


## === Sample Events ===

# Turns an EventConfig into concrete Event objects: for each Category,
# draws n_draws distinct dates within its date_range, and for each date
# creates one Event per Section (sections of one draw share that date).
#
# Date uniqueness is tracked per category, not globally, so two different
# categories can coincidentally land on the same date;
# the same-day conflict check in assign_events! handles it.
function sample_events(event_config::EventConfig, rng)
    events = Vector{Event}()

    for category in event_config.categories
        used_dates = Set{Int}()  # track dates used by this category

        for draw in 1:category.n_draws
            available_dates = setdiff(category.date_range[1]:category.date_range[2], used_dates)

            if isempty(available_dates)
                error("Category $(category.name): date_range $(category.date_range) has only " *
                      "$(length(category.date_range[1]:category.date_range[2])) day(s) available, " *
                      "not enough unique dates for $(category.n_draws) draws.")
            end

            date = rand(rng, available_dates)
            push!(used_dates, date)

            for section in category.sections
                n = rand(rng, section.n_range[1]:section.n_range[2])
                id = "$(category.id)_$(draw)_$(section.id)"

                # Build a readable name from whatever parts apply; falls back to id.
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
                    std_contacts=section.std_contacts,
                    cross_section_mean_contacts=category.cross_section_mean_contacts,
                    cross_section_std_contacts=category.cross_section_std_contacts
                ))
            end
        end
    end

    return events
end


## === Prepare Population ===

# Loads the base population and adds every column the rest of the project
# needs: age-group labels, empty per-person event-attendance records,
# superspreader status, and each  person's transmission_prob.
#
# Reads general_rate, std_rate, superspreader_prob, superspreader_rate,
# superspreader_std from global scope (set in 1_UserConfig.jl).
#
# The attendance columns added here (category_ids, draw_ids, section_ids,
# mean_event_contacts, std_event_contacts, event_dates) are also listed in
# 2_Interface.jl's ind_extension, which is how GEMS carries them onto its
# own Individual objects for 4_Contacts.jl and 5_Transmission.jl to read.
function prepare_population(event_config::EventConfig, rng)
    people = JLD2.load(joinpath(@__DIR__, "Datastorage", "people_Saalekreis.jld2"))["data"]

    age_boundaries = event_config.age_boundaries
    age_groups = [age_group_label_from_idx(i, age_boundaries) for i in 1:(length(age_boundaries)+1)]
    sex_levels = [1, 2]

    people.age_group = age_group_label.(people.age, Ref(age_boundaries))
    people.age_group = categorical(people.age_group; ordered=true, levels=age_groups)

    people.category_ids = [Int32[] for _ in 1:nrow(people)]
    people.draw_ids = [Int32[] for _ in 1:nrow(people)]
    people.section_ids = [Int32[] for _ in 1:nrow(people)]
    people.mean_event_contacts = [Float64[] for _ in 1:nrow(people)]
    people.event_dates = [Int32[] for _ in 1:nrow(people)]
    people.std_event_contacts = [Float64[] for _ in 1:nrow(people)]
    people.cross_section_mean_contacts = [Float64[] for _ in 1:nrow(people)]
people.cross_section_std_contacts = [Float64[] for _ in 1:nrow(people)]

    α_normal, β_normal = gamma_params(general_rate, std_rate)
    α_super, β_super = gamma_params(superspreader_rate, superspreader_std)

    people.is_superspreader = [rand(rng) < superspreader_prob for _ in 1:nrow(people)]
    # Gamma is unbounded above, so clamp to 1.0 since this is used as a probability.
    people.transmission_prob = Float64[
        min(1.0, people.is_superspreader[i] ?
                 rand(rng, Gamma(α_super, β_super)) :
                 rand(rng, Gamma(α_normal, β_normal)))
        for i in 1:nrow(people)
    ]

    return people, age_groups, sex_levels
end


## === Compute Weights ===

# Computes per-candidate sampling weights for demographic-targeted event
# selection, used by assign_events! for both core-group and random-pool draws.
#
# Weights are per-capita: each candidate's weight is the target share
# (age_weight times sex_weight) divided by how many candidates share their
# (age_group, sex) cell. This keeps a cell's total pull equal to its
# intended target share regardless of how many candidates happen to fall
# into it — without dividing, a larger candidate pool would pull more than
# its intended share just by having more people in it.
#
# Cells with zero candidates get weight 0; if their target share is
# nonzero, sampling redistributes it proportionally across the other cells.
function compute_weights(people, candidates, category, event_config)
    age_boundaries = event_config.age_boundaries
    n_groups = length(age_boundaries) + 1

    ages = people.age
    sexes = people.sex

    gidx = Vector{Int}(undef, length(candidates))
    for (k, idx) in enumerate(candidates)
        gidx[k] = age_group_idx(ages[idx], age_boundaries)
    end

    counts = zeros(Int, n_groups, 2)
    for (k, idx) in enumerate(candidates)
        counts[gidx[k], sexes[idx]] += 1
    end

    weights = Vector{Float64}(undef, length(candidates))
    for (k, idx) in enumerate(candidates)
        g = gidx[k]
        sex = sexes[idx]

        # category age_weights/sex_weights override EventConfig.age_dist/sex_dist if given
        aw = isempty(category.age_weights) ?
             event_config.age_dist[g] :
             category.age_weights[g]

        sw = isempty(category.sex_weights) ?
             event_config.sex_dist[g][sex] :
             category.sex_weights[sex]

        c = counts[g, sex]
        weights[k] = c > 0 ? (aw * sw) / c : 0.0
    end

    return weights
end


## === Assign Events ===

# Assigns people to every event, mutating `people`'s attendance columns and
# returning attendees::Dict{String,Vector{Int}} (event id to attendee
# row-indices)
#
# Requires `events` to already be sorted chronologically (2_Interface.jl
# does this before calling). Loyalty tracking and the same-day conflict
# check both depend on events being processed in calendar order; passing
# unsorted events won't error, it will silently produce wrong loyalty
# behavior.
#
# Two phases: first, build each category's core group once, up front (a
# person can be core for at most one category). Then, for each event in
# order, add its core members (skipping same-day conflicts), and fill the
# rest from a demographically-weighted random draw with loyalty-based
# reweighting for repeat attendees.
function assign_events!(people::DataFrame, events::Vector{Event}, event_config::EventConfig, rng)
    loyal_pools = Dict{Int,Set{Int}}()
    core_groups = Dict{Int,Vector{Int}}()
    all_core_members = Set{Int}()
    attendees = Dict{String,Vector{Int}}()
    base_candidates_by_category = Dict{Int,Vector{Int}}()

    event_dates_col = people.event_dates

    # --- PHASE 1: build each category's core group once (unchanged) ---
    for category in event_config.categories
        cat_events = filter(e -> e.category_id == category.id, events)
        isempty(cat_events) && continue
        min_n = minimum(e.n for e in cat_events)
        n_core_total = round(Int, min_n * category.core)

        base_candidates = findall(
            (people.age .>= category.min_age) .&
            (people.age .<= category.max_age)
        )
        base_candidates_by_category[category.id] = base_candidates

        core_groups[category.id] = Int[]

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

        n_regular_core = max(0, n_core_total - length(core_groups[category.id]))
        if n_regular_core > 0
            core_so_far = Set(core_groups[category.id])
            remaining_for_core = filter(idx ->
                    idx ∉ core_so_far &&
                    idx ∉ all_core_members,
                base_candidates)
            core_weights = compute_weights(people, remaining_for_core, category, event_config)
            n_to_sample = min(n_regular_core, length(remaining_for_core))
            regular_core = sample(rng, remaining_for_core, Weights(core_weights), n_to_sample, replace=false)
            append!(core_groups[category.id], regular_core)
        end

        union!(all_core_members, core_groups[category.id])
    end

    # --- PHASE 2: assign attendees event by event, in chronological order ---
    for event in events
        category = event_config.categories[findfirst(c -> c.id == event.category_id, event_config.categories)]
        base_candidates = base_candidates_by_category[category.id]

        selected = Int[]

        # core group, minus anyone already booked elsewhere this exact day
        if haskey(core_groups, category.id)
            available_core = filter(idx ->
                    event.date ∉ event_dates_col[idx],
                core_groups[category.id])
            append!(selected, available_core)
        end

        n_remaining = event.n - length(selected)

        # loyalty: guaranteed, demographically-weighted fraction of the non-core
        # spots goes to people who've attended this category as non-core before
        # (any prior draw — pool only grows, never expires). Capped at n_remaining
        # in addition to eligible pool size, so a misconfigured loyalty > 1 can't
        # overflow the event beyond its target size (same overflow risk core had
        # before it got the same kind of cap).
        loyalty_selected = Int[]
        if category.loyalty > 0.0 && haskey(loyal_pools, category.id) && n_remaining > 0
            selected_set = Set(selected)
            eligible = [idx for idx in loyal_pools[category.id]
                        if idx ∉ selected_set && event.date ∉ event_dates_col[idx]]
            n_loyalty = max(0, min(round(Int, category.loyalty * n_remaining), n_remaining, length(eligible)))
            if n_loyalty > 0
                loyalty_weights = compute_weights(people, eligible, category, event_config)
                loyalty_selected = sample(rng, eligible, Weights(loyalty_weights), n_loyalty, replace=false)
                append!(selected, loyalty_selected)
            end
        end

        # random pool fills whatever's left
        n_remaining_after_loyalty = event.n - length(selected)
        selected_set = Set(selected)
        remaining = filter(idx ->
                idx ∉ selected_set &&
                event.date ∉ event_dates_col[idx],
            base_candidates)

        remaining_weights = compute_weights(people, remaining, category, event_config)

        n_to_sample = min(n_remaining_after_loyalty, length(remaining))
        random_selected = Int[]
        if n_to_sample > 0
            random_selected = sample(rng, remaining, Weights(remaining_weights), n_to_sample, replace=false)
            append!(selected, random_selected)
        end

        # anyone selected today who isn't core becomes (or remains) loyalty-eligible
        if !haskey(loyal_pools, category.id)
            loyal_pools[category.id] = Set{Int}()
        end
        union!(loyal_pools[category.id], loyalty_selected)
        union!(loyal_pools[category.id], random_selected)

        attendees[event.id] = copy(selected)

        for idx in selected
            push!(people.category_ids[idx], Int32(event.category_id))
            push!(people.draw_ids[idx], Int32(event.draw_id))
            push!(people.section_ids[idx], Int32(event.section_id))
            push!(people.mean_event_contacts[idx], event.mean_contacts)
            push!(people.std_event_contacts[idx], event.std_contacts)
            push!(people.event_dates[idx], Int32(event.date))
            push!(people.cross_section_mean_contacts[idx], event.cross_section_mean_contacts)
            push!(people.cross_section_std_contacts[idx], event.cross_section_std_contacts)
        end
    end

    return attendees
end


println("End Population")