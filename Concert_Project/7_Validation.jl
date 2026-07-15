# 7_Validation.jl
# Run after simulation and analysis — requires: people, events, aggregated, event_config

function validate_assignment(people::DataFrame, events::Vector{Event})
    println("\n=== Assignment Validation ===")

    total_assigned = sum(length(row.event_ids) > 0 for row in eachrow(people))
    multi_assigned = sum(length(row.event_ids) > 1 for row in eachrow(people))
    println("People attending at least one event: $total_assigned")
    println("People attending multiple events:    $multi_assigned")

    for event in events
        assigned = sum(
            any(row.event_ids .== event.category_id) &&
            any(row.section_ids .== event.section_id) &&
            any(row.event_dates .== event.date)
            for row in eachrow(people)
        )
        status = assigned ≈ event.n ? "✓" : "✗ expected $(event.n)"
        println("Event $(event.id) (date=$(event.date), n=$(event.n)): $assigned assigned $status")
    end

    println("Unassigned: $(nrow(people) - total_assigned) / $(nrow(people))")
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


function validate_expected_vs_observed(aggregated::Dict, events::Vector{Event}, event_config::EventConfig)
    println("\n=== Expected vs Observed ===")

    for event in events
        metrics = aggregated[event.id]
        n_section = event.n
        infectious = metrics[:infectious].mean
        susceptible = metrics[:susceptible].mean
        infected_at_event = metrics[:infected_at_event].mean

        exponent = n_section > 1 ?
                   infectious * event.mean_contacts *
                   event_config.transmission_rate / (n_section - 1) : 0.0
        p_infected = 1 - exp(-exponent)
        expected   = susceptible * p_infected
        std_val    = sqrt(susceptible * p_infected * (1 - p_infected))
        z_score    = std_val > 0 ? (infected_at_event - expected) / std_val : 0.0

        println("\nEvent $(event.id) — Day $(event.date)")
        println("  Infectious at event:  $(fmt(infectious))")
        println("  Susceptible:          $(fmt(susceptible))")
        println("  Expected infections:  $(fmt(expected)) ± $(fmt(std_val))")
        println("  Observed infections:  $(fmt(infected_at_event))")
        println("  Z-score:              $(fmt(z_score))")
    end
end


# === Auto-run validation ===
validate_assignment(people, events)
validate_results(aggregated, events)
validate_expected_vs_observed(aggregated, events, event_config)