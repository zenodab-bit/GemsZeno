function analyze_event_population(inf_log::DataFrame, event_lookup::Dict, event_config::EventConfig, run_validation::Bool=false)
    results = Dict{Int, Any}()

    for event in event_config.events
        section_results = Dict{String, Any}()

        for section in event.sections
            section_num = parse(Int32, split(section.id, "_")[2])

            # get individual ids for this section from lookup
            section_ids = Set{Int32}(id for (id, v) in event_lookup 
                                     if v.event_id == event.id && 
                                        v.section_id == section_num)

            # categorize people from infection log
            infected_before_ids = Set{Int32}()
            currently_infectious_ids = Set{Int32}()
            exposed_before_ids = Set{Int32}()
            recovered_ids = Set{Int32}()
            dead_ids = Set{Int32}()
            same_day_other_ids = Set{Int32}()
            event_infected_ids = Set{Int32}()

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

            # compute counts for this section
            not_susceptible_ids = union(infected_before_ids, same_day_other_ids)
            susceptible     = length(setdiff(section_ids, not_susceptible_ids))
            infectious      = length(intersect(currently_infectious_ids, section_ids))
            exposed         = length(intersect(exposed_before_ids, section_ids))
            recovered       = length(intersect(recovered_ids, section_ids))
            dead            = length(intersect(dead_ids, section_ids))
            same_day_other  = length(intersect(same_day_other_ids, section_ids))
            infected_at_event = length(intersect(event_infected_ids, section_ids))

            section_data = (
                susceptible       = susceptible,
                infectious        = infectious,
                exposed           = exposed,
                recovered         = recovered,
                dead              = dead,
                same_day_other    = same_day_other,
                infected_at_event = infected_at_event
            )

            # validation metrics
            if run_validation
                n_section = length(section_ids)
                exponent = n_section > 1 ? 
                           infectious * section.mean_event_contacts * 
                           event_config.transmission_rate / (n_section - 1) : 0.0
                p_infected = 1 - exp(-exponent)
                expected   = susceptible * p_infected
                std_val    = sqrt(susceptible * p_infected * (1 - p_infected))
                z_score    = std_val > 0 ? (infected_at_event - expected) / std_val : 0.0

                section_data = merge(section_data, (
                    expected = expected,
                    std      = std_val,
                    z_score  = z_score
                ))
            end

            section_results[section.id] = section_data
        end

        results[event.id] = section_results
    end

    return results
end


function aggregate_event_results(results_vector::Vector{Any})
    aggregated = Dict{Int, Any}()
    first_result = results_vector[1]

    for (event_id, section_results) in first_result
        aggregated[event_id] = Dict{String, Any}()
        for (section_id, _) in section_results
            fields = keys(results_vector[1][event_id][section_id])
            aggregated[event_id][section_id] = Dict{Symbol, NamedTuple}()
            for field in fields
                values = Float64[getfield(results_vector[r][event_id][section_id], field)
                                 for r in 1:length(results_vector)]
                aggregated[event_id][section_id][field] = (
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
    end

    return aggregated
end