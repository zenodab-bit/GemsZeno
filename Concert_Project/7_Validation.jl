# 7_Validation.jl
# Run after simulation and analysis — requires: people, events, aggregated, event_config

function validate_assignment(people::DataFrame, events::Vector{Event})
    println("\n=== Assignment Validation ===")

    total_assigned = sum(length(row.event_ids) > 0 for row in eachrow(people))
    multi_assigned = sum(length(row.event_ids) > 1 for row in eachrow(people))

    attendance_counts = countmap(length(row.event_ids) for row in eachrow(people))
    println("\nAttendance distribution:")
    for n in sort(collect(keys(attendance_counts)))
        if n == 0
            println("  0 events: $(attendance_counts[n]) people (unassigned)")
        else
            println("  $n event(s): $(attendance_counts[n]) people")
        end
    end

    println("\nPeople attending at least one event: $total_assigned")
    println("People attending multiple events:    $multi_assigned")

    for event in events
        assigned = sum(
            any((row.category_ids .== event.category_id) .&
                (row.event_ids .== event.draw_id) .&
                (row.section_ids .== event.section_id) .&
                (row.event_dates .== event.date))
            for row in eachrow(people)
        )
        status = assigned ≈ event.n ? "✓" : "✗ expected $(event.n)"
        println("Event $(event.id) (date=$(event.date), n=$(event.n)): $assigned assigned $status")
    end

    println("Unassigned: $(nrow(people) - total_assigned) / $(nrow(people))")
end

function validate_loyalty(people::DataFrame, events::Vector{Event}, event_config::EventConfig)
    println("\n=== Loyalty Validation ===")

    for category in event_config.categories
        category.loyalty == 0.0 && continue

        cat_events = filter(e -> e.category_id == category.id, events)
        length(cat_events) <= 1 && continue

        println("\nCategory $(category.id) — loyalty=$(category.loyalty)")

        # build attendee sets per draw
        draw_attendees = [Set{Int32}(row.id for row in eachrow(people)
                                                if any((row.category_ids .== e.category_id) .&
                                                    (row.event_ids .== e.draw_id) .&
                                                    (row.section_ids .== e.section_id) .&
                                                    (row.event_dates .== e.date)))
                          for e in cat_events]

        # cumulative loyal pool
        loyal_pool = Set{Int32}()
        union!(loyal_pool, draw_attendees[1])

        for i in 2:length(cat_events)
            current_event = cat_events[i]
            n_core = round(Int, current_event.n * category.core)
            n_loyal_expected = round(Int, (current_event.n - n_core) * category.loyalty)
            expected_overlap = n_core + n_loyal_expected
            overlap = length(intersect(draw_attendees[i], loyal_pool))
            status = overlap ≈ expected_overlap ? "✓" : "✗"
            println("  Draw $(current_event.draw_id): $overlap repeat attendees from pool of $(length(loyal_pool)) (expected ~$expected_overlap)")
            union!(loyal_pool, draw_attendees[i])  # add CURRENT draw, not previous
        end
    end
end


function validate_results(aggregated::Dict, events::Vector{Event})
    println("\n=== Results Validation ===")

    for event in events
        metrics = aggregated[event.id]
        println("\nEvent $(event.id) — Day $(event.date) — n=$(event.n)")

        # infected at event should not exceed section size
        if metrics[:infected_at_event].max > event.n
            println("  ✗ infected_at_event max ($(metrics[:infected_at_event].max)) exceeds section size ($(event.n))")
        else
            println("  ✓ infected_at_event within bounds")
        end

        # susceptible + infected + exposed + recovered + dead should equal section size
        total = metrics[:susceptible].mean + metrics[:infectious].mean +
                metrics[:exposed].mean + metrics[:recovered].mean +
                metrics[:dead].mean + metrics[:same_day_other].mean
        if abs(total - event.n) > 1.0  # allow small rounding error
            println("  ✗ compartment totals ($(fmt(total))) don't match section size ($(event.n))")
        else
            println("  ✓ compartment totals match section size")
        end
    end
end



function validate_demographics(people::DataFrame, events::Vector{Event}, event_config::EventConfig)
    println("\n=== Demographic Validation ===")

    for category in event_config.categories
        cat_events = filter(e -> e.category_id == category.id, events)
        isempty(cat_events) && continue

        println("\nCategory $(category.id) — loyalty=$(category.loyalty):")

        for event in cat_events
            # get attendees of this specific event
            attendees = filter(row ->
                    any((row.category_ids .== event.category_id) .&
                        (row.event_ids .== event.draw_id) .&
                        (row.section_ids .== event.section_id) .&
                        (row.event_dates .== event.date)),
                eachrow(people))
            n = length(attendees)

            println("\n  Event $(event.id) (day=$(event.date), n=$(event.n)):")

            # age distribution
            println("    Age distribution:")
            for i in 1:length(event_config.age_boundaries)
                boundary = event_config.age_boundaries[i]
                expected = isempty(category.age_weights) ?
                           event_config.age_dist[i] :
                           category.age_weights[i] / sum(category.age_weights)
                actual_count = count(row -> age_group_idx(row.age, event_config.age_boundaries) == i, attendees)
                actual = n > 0 ? actual_count / n : 0.0
                println("      <=$boundary: expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")
            end
            # last age group
            i = length(event_config.age_boundaries) + 1
            expected = isempty(category.age_weights) ?
                       event_config.age_dist[i] :
                       category.age_weights[i] / sum(category.age_weights)
            actual_count = count(row -> age_group_idx(row.age, event_config.age_boundaries) == i, attendees)
            actual = n > 0 ? actual_count / n : 0.0
            println("      >$(event_config.age_boundaries[end]): expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")

            # sex distribution
            println("    Sex distribution:")
            for (s, label) in [(1, "Male"), (2, "Female")]
                expected = isempty(category.sex_weights) ? 0.5 : category.sex_weights[s] / sum(category.sex_weights)
                actual_count = count(row -> row.sex == s, attendees)
                actual = n > 0 ? actual_count / n : 0.0
                println("      $label: expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")
            end
        end
    end
end

function validate_epidemic_state(aggregated, events, bd, event_config)
    println("\n=== Epidemic State Validation ===")

    tc_infectious = tick_cases(bd)["infectious_cnt"]
    tc_exposed    = tick_cases(bd)["exposed_cnt"]
    tc_recovered  = tick_cases(bd)["recovered_cnt"]
    tc_dead       = tick_cases(bd)["dead_cnt"]
    pop_size      = nrow(people)

    function print_validation_row(label, expected, observed, std)
        z = std > 0 ? (observed - expected) / std : 0.0
        println("  $(rpad(label, 20)) $(rpad(fmt(expected), 12)) $(rpad(fmt(observed), 12)) $(fmt(z))")
    end

    for event in events
        metrics = aggregated[event.id]

        row_inf  = tc_infectious[tc_infectious.tick .== event.date, :]
        row_exp  = tc_exposed[tc_exposed.tick .== event.date, :]
        row_rec  = tc_recovered[tc_recovered.tick .== event.date, :]
        row_dead = tc_dead[tc_dead.tick .== event.date, :]

        isempty(row_inf) && continue

        expected_infectious  = (row_inf.mean[1]  / pop_size) * event.n
        expected_exposed     = (row_exp.mean[1]  / pop_size) * event.n
        expected_recovered   = (row_rec.mean[1]  / pop_size) * event.n
        expected_dead        = (row_dead.mean[1] / pop_size) * event.n
        expected_susceptible = event.n - expected_infectious - expected_exposed -
                               expected_recovered - expected_dead

        # expected infections at event
        n_section    = event.n
        exponent     = n_section > 1 ?
                       metrics[:infectious].mean * event.mean_contacts *
                       event_config.transmission_rate / (n_section - 1) : 0.0
        p_infected   = 1 - exp(-exponent)
        expected_infected = metrics[:susceptible].mean * p_infected
        std_infected      = sqrt(metrics[:susceptible].mean * p_infected * (1 - p_infected))

        println("\nEvent $(event.id) — Day $(event.date) — n=$(event.n)")
        println("  $(rpad("", 20)) $(rpad("Expected", 12)) $(rpad("Observed", 12)) Z-score")
        println("  " * "-"^55)
        print_validation_row("Susceptible",  expected_susceptible,  metrics[:susceptible].mean,  metrics[:susceptible].std)
        print_validation_row("Infectious",   expected_infectious,   metrics[:infectious].mean,   metrics[:infectious].std)
        print_validation_row("Exposed",      expected_exposed,      metrics[:exposed].mean,      metrics[:exposed].std)
        print_validation_row("Recovered",    expected_recovered,    metrics[:recovered].mean,    metrics[:recovered].std)
        print_validation_row("Dead",         expected_dead,         metrics[:dead].mean,         metrics[:dead].std)
        println("  " * "-"^55)
        print_validation_row("Infected",     expected_infected,     metrics[:infected_at_event].mean, std_infected)
    end
end

# === Auto-run validation ===
validate_assignment(people, events)
validate_loyalty(people, events, event_config)
validate_results(aggregated, events)
validate_demographics(people, events, event_config)
validate_epidemic_state(aggregated, events, bd, event_config)