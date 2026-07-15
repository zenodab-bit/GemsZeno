function analyze_event_population(inf_log::DataFrame, people::DataFrame, events::Vector{Event})
    results = Dict{String, Any}()

    for event in events
        # get individual ids for this event from people DataFrame
        section_ids = Set{Int32}()
        for row in eachrow(people)
            for i in eachindex(row.event_ids)
                if row.event_ids[i] == event.category_id &&
                   row.section_ids[i] == event.section_id &&
                   row.event_dates[i] == event.date
                    push!(section_ids, row.id)
                end
            end
        end

        # categorize people from infection log
        infected_before_ids    = Set{Int32}()
        currently_infectious_ids = Set{Int32}()
        exposed_before_ids     = Set{Int32}()
        recovered_ids          = Set{Int32}()
        dead_ids               = Set{Int32}()
        same_day_other_ids     = Set{Int32}()
        event_infected_ids     = Set{Int32}()

        for row in eachrow(inf_log)
            if row.tick < event.date
                push!(infected_before_ids, row.id_b)
                if row.infectiousness_onset <= event.date &&
                   (row.recovery > event.date || row.recovery == -1) &&
                   (row.death > event.date || row.death == -1)
                    push!(currently_infectious_ids, row.id_b)
                elseif row.recovery != -1 && row.recovery <= event.date
                    push!(recovered_ids, row.id_b)
                elseif row.death != -1 && row.death <= event.date
                    push!(dead_ids, row.id_b)
                else
                    push!(exposed_before_ids, row.id_b)
                end
            elseif row.tick == event.date
                if row.setting_type != 'g'
                    push!(same_day_other_ids, row.id_b)
                else
                    push!(event_infected_ids, row.id_b)
                end
            end
        end

        # compute counts
        not_susceptible_ids = union(infected_before_ids, same_day_other_ids)
        susceptible       = length(setdiff(section_ids, not_susceptible_ids))
        infectious        = length(intersect(currently_infectious_ids, section_ids))
        exposed           = length(intersect(exposed_before_ids, section_ids))
        recovered         = length(intersect(recovered_ids, section_ids))
        dead              = length(intersect(dead_ids, section_ids))
        same_day_other    = length(intersect(same_day_other_ids, section_ids))
        infected_at_event = length(intersect(event_infected_ids, section_ids))

        event_data = (
            susceptible       = susceptible,
            infectious        = infectious,
            exposed           = exposed,
            recovered         = recovered,
            dead              = dead,
            same_day_other    = same_day_other,
            infected_at_event = infected_at_event
        )

        results[event.id] = event_data
    end

    return results
end


function aggregate_event_results(results_vector::Vector{Any})
    aggregated = Dict{String, Any}()
    first_result = results_vector[1]

    for (event_id, _) in first_result
        fields = keys(results_vector[1][event_id])
        aggregated[event_id] = Dict{Symbol, NamedTuple}()
        for field in fields
            values = Float64[getfield(results_vector[r][event_id], field)
                             for r in 1:length(results_vector)]
            aggregated[event_id][field] = (
                mean   = mean(values),
                std    = length(values) > 1 ? std(values) : 0.0,
                min    = minimum(values),
                p25    = quantile(values, 0.25),
                median = median(values),
                p75    = quantile(values, 0.75),
                max    = maximum(values)
            )
        end
    end

    return aggregated
end