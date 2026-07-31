# ===========================================================================
# 7_Validation.jl
#
# Auto-run at the end of 2_Interface.jl, after 6_Analysis.jl, if
# run_validation is true. Four independent checks against the finished
# simulation: did assignment hit its targets, do compartment totals add
# up, does demographics match the config, and does the epidemic state
# roughly match what the population-wide infection log implies.
# ===========================================================================

# Population-wide SEIR compartment counts as of `tick`, computed directly
# from the infection log (not from tick_cases, which turned out to report
# same-day incidence rather than cumulative prevalence). Used by
# validate_epidemic_state as the population-wide baseline.
function population_compartment_counts(inf_log::DataFrame, tick::Int, pop_size::Int)
    infectious = 0
    exposed = 0
    recovered = 0
    dead = 0

    for row in eachrow(inf_log)
        row.tick >= tick && continue
        if row.infectiousness_onset <= tick &&
           (row.recovery > tick || row.recovery == -1) &&
           (row.death > tick || row.death == -1)
            infectious += 1
        elseif row.recovery != -1 && row.recovery <= tick
            recovered += 1
        elseif row.death != -1 && row.death <= tick
            dead += 1
        else
            exposed += 1
        end
    end

    susceptible = pop_size - infectious - exposed - recovered - dead
    return (susceptible=susceptible, infectious=infectious, exposed=exposed,
        recovered=recovered, dead=dead)
end

# Prints attendance distribution (who attended how many events, with a
# core/non-core breakdown where it applies) and confirms each event hit
# its target attendee count.
function validate_assignment(people::DataFrame, events::Vector{Event}, event_config::EventConfig, attendees::Dict{String,Vector{Int}})
    println("\n=== Assignment Validation ===")

    # attendance count per person, derived from attendees (touches only assigned people, not the full population)
    attendance_per_person = Dict{Int,Int}()
    for idxs in values(attendees)
        for idx in idxs
            attendance_per_person[idx] = get(attendance_per_person, idx, 0) + 1
        end
    end
    total_assigned = length(attendance_per_person)
    multi_assigned = count(>(1), values(attendance_per_person))

    # a person can attend at most one section per draw (same-day conflict), so
    # the true max attendance for a category is n_draws, not n_draws * sections
    core_sizes = Dict{Int,Int}()
    max_draws = Dict{Int,Int}()
    for category in event_config.categories
        cat_events = filter(e -> e.category_id == category.id, events)
        isempty(cat_events) && continue
        min_n = minimum(e.n for e in cat_events)
        core_sizes[category.id] = round(Int, min_n * category.core)
        max_draws[category.id] = category.n_draws
    end

    attendance_counts = countmap(values(attendance_per_person))
    println("\nAttendance distribution:")
    n_unassigned = nrow(people) - total_assigned
    println("  0 events: $n_unassigned people (unassigned)")
    for n in sort(collect(keys(attendance_counts)))
        core_note = ""
        for (cat_id, max_att) in max_draws
            if n == max_att && haskey(core_sizes, cat_id)
                core_note = " ($(core_sizes[cat_id]) core + $(attendance_counts[n] - core_sizes[cat_id]) non-core)"
            end
        end
        println("  $n event(s): $(attendance_counts[n]) people$core_note")
    end

    println("\nPeople attending at least one event: $total_assigned")
    println("People attending multiple events:    $multi_assigned")

    for event in events
        assigned = length(attendees[event.id])
        status = assigned == event.n ? "✓" : "✗ expected $(event.n)"
        println("Event $(event.id) (date=$(event.date), n=$(event.n)): $assigned assigned $status")
    end

    println("Unassigned: $(nrow(people) - total_assigned) / $(nrow(people))")
end


# Checks, per event: infected_at_event never exceeds the event size, and
# every compartment sums back to the event size (within rounding).
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


# Compares each event's actual attendee age/sex distribution against the
# category's (or, if unset, the population-wide) target.
function validate_demographics(people::DataFrame, events::Vector{Event}, event_config::EventConfig, attendees::Dict{String,Vector{Int}})
    println("\n=== Demographic Validation ===")

    for category in event_config.categories
        cat_events = filter(e -> e.category_id == category.id, events)
        isempty(cat_events) && continue

        println("\nCategory $(category.id) — loyalty=$(category.loyalty):")

        for event in cat_events
            idxs = attendees[event.id]
            n = length(idxs)
            ages = people.age[idxs]
            sexes = people.sex[idxs]

            println("\n  Event $(event.id) (day=$(event.date), n=$(event.n)):")

            println("    Age distribution:")
            for i in 1:length(event_config.age_boundaries)
                boundary = event_config.age_boundaries[i]
                expected = isempty(category.age_weights) ?
                           event_config.age_dist[i] :
                           category.age_weights[i] / sum(category.age_weights)
                actual_count = count(age -> age_group_idx(age, event_config.age_boundaries) == i, ages)
                actual = n > 0 ? actual_count / n : 0.0
                println("      <=$boundary: expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")
            end
            i = length(event_config.age_boundaries) + 1
            expected = isempty(category.age_weights) ?
                       event_config.age_dist[i] :
                       category.age_weights[i] / sum(category.age_weights)
            actual_count = count(age -> age_group_idx(age, event_config.age_boundaries) == i, ages)
            actual = n > 0 ? actual_count / n : 0.0
            println("      >$(event_config.age_boundaries[end]): expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")

            println("    Sex distribution:")
            for (s, label) in [(1, "Male"), (2, "Female")]
                expected = isempty(category.sex_weights) ? 0.5 : category.sex_weights[s] / sum(category.sex_weights)
                actual_count = count(==(s), sexes)
                actual = n > 0 ? actual_count / n : 0.0
                println("      $label: expected $(fmt(expected*100))% actual $(fmt(actual*100))% ($actual_count/$n)")
            end
        end
    end
end


# Compares each event's actual compartment counts against an analytically
# expected value (population-wide prevalence scaled to event size, plus a
# transmission-probability estimate for infected_at_event), as a Z-score.
# The transmission rate used is the mean transmission_prob across this
# event's actual attendees, not a flat population-wide constant — this
# matters when categories concentrate superspreaders (via min_superspreaders
# or core targeting), since a flat rate would systematically underestimate
# expected infections for those events.
function validate_epidemic_state(aggregated, events, bd, event_config, people, attendees)
    println("\n=== Epidemic State Validation ===")

    pop_size = nrow(people)
    unique_dates = unique(e.date for e in events)

    counts_per_date = Dict(date => NamedTuple[] for date in unique_dates)
    for rd in runs(bd)
        inf_log = infections(rd)
        for date in unique_dates
            push!(counts_per_date[date], population_compartment_counts(inf_log, date, pop_size))
        end
    end

    pop_counts = Dict(
        date => (
            infectious=mean(c.infectious for c in cs),
            exposed=mean(c.exposed for c in cs),
            recovered=mean(c.recovered for c in cs),
            dead=mean(c.dead for c in cs),
        )
        for (date, cs) in counts_per_date
    )

    # z_str is "n/a" rather than a Z-score of 0 when std == 0 (e.g. with a
    # single simulation replicate), since 0 would misleadingly look like a
    # perfect match rather than "no variance to compare against."
    function print_validation_row(label, expected, observed, std)
        z_str = std > 0 ? fmt((observed - expected) / std) : "n/a"
        println("  $(rpad(label, 20)) $(rpad(fmt(expected), 12)) $(rpad(fmt(observed), 12)) $z_str")
    end

    for event in events
        metrics = aggregated[event.id]
        pc = pop_counts[event.date]

        expected_infectious = (pc.infectious / pop_size) * event.n
        expected_exposed = (pc.exposed / pop_size) * event.n
        expected_recovered = (pc.recovered / pop_size) * event.n
        expected_dead = (pc.dead / pop_size) * event.n
        expected_susceptible = event.n - expected_infectious - expected_exposed -
                               expected_recovered - expected_dead

        n_section = event.n
        event_transmission_rate = mean(people.transmission_prob[idx] for idx in attendees[event.id])
        exponent = n_section > 1 ?
                   metrics[:infectious].mean * event.mean_contacts *
                   event_transmission_rate / (n_section - 1) : 0.0
        p_infected = 1 - exp(-exponent)
        expected_infected = metrics[:susceptible].mean * p_infected
        std_infected = sqrt(metrics[:susceptible].mean * p_infected * (1 - p_infected))

        println("\nEvent $(event.id) — Day $(event.date) — n=$(event.n)")
        println("  $(rpad("", 20)) $(rpad("Expected", 12)) $(rpad("Observed", 12)) Z-score")
        println("  " * "-"^55)
        print_validation_row("Susceptible", expected_susceptible, metrics[:susceptible].mean, metrics[:susceptible].std)
        print_validation_row("Infectious", expected_infectious, metrics[:infectious].mean, metrics[:infectious].std)
        print_validation_row("Exposed", expected_exposed, metrics[:exposed].mean, metrics[:exposed].std)
        print_validation_row("Recovered", expected_recovered, metrics[:recovered].mean, metrics[:recovered].std)
        print_validation_row("Dead", expected_dead, metrics[:dead].mean, metrics[:dead].std)
        println("  " * "-"^55)
        print_validation_row("Infected", expected_infected, metrics[:infected_at_event].mean, std_infected)
    end
end


# === Auto-run validation ===

validate_assignment(people, events, event_config, attendees)
validate_results(aggregated, events)
validate_demographics(people, events, event_config, attendees)
validate_epidemic_state(aggregated, events, bd, event_config, people, attendees)

println("End Validation")