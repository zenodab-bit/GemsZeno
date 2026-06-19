

function analyze_concert_population(sim, concert_date, sitting_rate, standing_rate,
    mean_number_of_contacts_sitting,
    mean_number_of_contacts_standing, actual_event_size)
    inf_logger = dataframe(infectionlogger(sim))
    infected_before_concert_ids = Set{Int32}()
    currently_infectious_ids = Set{Int32}()
    exposed_before_concert_ids = Set{Int32}()
    recovered_ids = Set{Int32}()
    dead_ids = Set{Int32}()
    same_day_other_ids = Set{Int32}()
    concert_infected_ids = Set{Int32}()

    for row in eachrow(inf_logger)
        if row.tick < concert_date
            push!(infected_before_concert_ids, row.id_b)
            if row.infectiousness_onset <= concert_date &&
               (row.recovery > concert_date || row.recovery == -1) &&
               (row.death > concert_date || row.death == -1)
                push!(currently_infectious_ids, row.id_b)
            elseif row.recovery != -1 && row.recovery <= concert_date
                push!(recovered_ids, row.id_b)
            elseif row.death != -1 && row.death <= concert_date
                push!(dead_ids, row.id_b)
            else
                push!(exposed_before_concert_ids, row.id_b)
            end
        elseif row.tick == concert_date
            if row.setting_type != 'g'
                push!(same_day_other_ids, row.id_b)
            else
                push!(concert_infected_ids, row.id_b)
            end
        end
    end

    sitting_ids = Set(i.id for i in sim.population.individuals if i.occupation == 1)
    standing_ids = Set(i.id for i in sim.population.individuals if i.occupation == 2)

    not_susceptible_ids = union(infected_before_concert_ids, same_day_other_ids)
    susceptible_sitting_ids = setdiff(sitting_ids, not_susceptible_ids)
    susceptible_standing_ids = setdiff(standing_ids, not_susceptible_ids)


    susceptible_sitting = length(susceptible_sitting_ids)
    susceptible_standing = length(susceptible_standing_ids)
    infectious_sitting = length(intersect(currently_infectious_ids, sitting_ids))
    infectious_standing = length(intersect(currently_infectious_ids, standing_ids))
    exposed_sitting = length(intersect(exposed_before_concert_ids, sitting_ids))
    exposed_standing = length(intersect(exposed_before_concert_ids, standing_ids))
    recovered_sitting = length(intersect(recovered_ids, sitting_ids))
    recovered_standing = length(intersect(recovered_ids, standing_ids))
    dead_sitting = length(intersect(dead_ids, sitting_ids))
    dead_standing = length(intersect(dead_ids, standing_ids))
    same_day_other_sitting = length(intersect(same_day_other_ids, sitting_ids))
    same_day_other_standing = length(intersect(same_day_other_ids, standing_ids))
    infected_sitting = length(intersect(concert_infected_ids, sitting_ids))
    infected_standing = length(intersect(concert_infected_ids, standing_ids))


    # sitting
    exponent_sitting = infectious_sitting * mean_number_of_contacts_sitting * sitting_rate / (length(sitting_ids) - 1)
    p_infected_sitting = 1 - exp(-exponent_sitting)
    expected_sitting = susceptible_sitting * p_infected_sitting
    std_sitting = sqrt(susceptible_sitting * p_infected_sitting * (1 - p_infected_sitting))
    z_sitting = std_sitting > 0 ? (infected_sitting - expected_sitting) / std_sitting : 0.0

    # standing
    exponent_standing = infectious_standing * mean_number_of_contacts_standing * standing_rate / (length(standing_ids) - 1)
    p_infected_standing = 1 - exp(-exponent_standing)
    expected_standing = susceptible_standing * p_infected_standing
    std_standing = sqrt(susceptible_standing * p_infected_standing * (1 - p_infected_standing))
    z_standing = std_standing > 0 ? (infected_standing - expected_standing) / std_standing : 0.0


    return (
        susceptible_sitting=susceptible_sitting,
        susceptible_standing=susceptible_standing,
        infectious_sitting=infectious_sitting,
        infectious_standing=infectious_standing,
        exposed_sitting=exposed_sitting,
        exposed_standing=exposed_standing,
        recovered_sitting=recovered_sitting,
        recovered_standing=recovered_standing,
        dead_sitting=dead_sitting,
        dead_standing=dead_standing,
        same_day_other_sitting=same_day_other_sitting,
        same_day_other_standing=same_day_other_standing,
        infected_sitting=infected_sitting,
        infected_standing=infected_standing, expected_sitting=expected_sitting,
        std_sitting=std_sitting,
        z_sitting=z_sitting, expected_standing=expected_standing,
        std_standing=std_standing,
        z_standing=z_standing,
    )
end



function aggregate_concert_results(results_vector)
    aggregated = Dict{Symbol,NamedTuple}()

    if length(results_vector) == 1
        r = results_vector[1]
        for field in keys(r)
            v = getfield(r, field)
            aggregated[field] = (
                mean=Float64(v),
                std=0.0,
                min=Float64(v),
                p25=Float64(v),
                median=Float64(v),
                p75=Float64(v),
                max=Float64(v)
            )
        end
    else
        for field in keys(results_vector[1])
            values = [getfield(r, field) for r in results_vector]
            aggregated[field] = (
                mean=mean(values),
                std=std(values),
                min=minimum(values),
                p25=quantile(values, 0.25),
                median=median(values),
                p75=quantile(values, 0.75),
                max=maximum(values)
            )
        end
    end
    return aggregated
end



## Chain of infections ##
function infected_by(inf_logger, source_ids)
    return Set(row.id_b for row in eachrow(inf_logger) if row.id_a in source_ids)
end

function transmission_chain(inf_logger, seed_ids)
    generations = Vector{Set{Int32}}()
    current_gen = seed_ids
    while !isempty(current_gen)
        next_gen = infected_by(inf_logger, current_gen)
        next_gen = setdiff(next_gen, reduce(union, generations, init=Set{Int32}()))
        isempty(next_gen) && break
        push!(generations, next_gen)
        current_gen = next_gen
    end
    return generations
end

function aggregate_chain_results(chain_vector)
    scalar_fields = [:total_downstream_sitting, :total_downstream_standing,
        :n_generations_sitting, :n_generations_standing]

    aggregated = Dict{Symbol,NamedTuple}()
    for field in scalar_fields
        values = Float64[getfield(r, field) for r in chain_vector]
        aggregated[field] = (
            mean=mean(values),
            std=length(values) > 1 ? std(values) : 0.0,
            min=minimum(values),
            p25=quantile(values, 0.25),
            median=median(values),
            p75=quantile(values, 0.75),
            max=maximum(values)
        )
    end

    # per-generation matrices stored separately
    max_gen_sit = maximum(length(r.downstream_sitting) for r in chain_vector)
    max_gen_sta = maximum(length(r.downstream_standing) for r in chain_vector)

    gen_sit_matrix = hcat([vcat(r.downstream_sitting, zeros(Int, max_gen_sit - length(r.downstream_sitting))) for r in chain_vector]...)
    gen_sta_matrix = hcat([vcat(r.downstream_standing, zeros(Int, max_gen_sta - length(r.downstream_standing))) for r in chain_vector]...)

    return (
        aggregated=aggregated,
        gen_sitting=gen_sit_matrix,
        gen_standing=gen_sta_matrix
    )
end

function analyze_transmission_chains(sim, concert_date)
    inf_logger = dataframe(infectionlogger(sim))

    # build occupation sets
    sitting_ids = Set(i.id for i in sim.population.individuals if i.occupation == 1)
    standing_ids = Set(i.id for i in sim.population.individuals if i.occupation == 2)

    # find everyone infected at the concert
    concert_infected_ids = Set{Int32}()
    for row in eachrow(inf_logger)
        if row.tick == concert_date && row.setting_type == 'g'
            push!(concert_infected_ids, row.id_b)
        end
    end

    # split by occupation
    concert_infected_sitting = intersect(concert_infected_ids, sitting_ids)
    concert_infected_standing = intersect(concert_infected_ids, standing_ids)

    # trace full transmission chains
    chain_sitting = transmission_chain(inf_logger, concert_infected_sitting)
    chain_standing = transmission_chain(inf_logger, concert_infected_standing)

    return (
        downstream_sitting=length.(chain_sitting),
        downstream_standing=length.(chain_standing),
        total_downstream_sitting=isempty(chain_sitting) ? 0 : sum(length.(chain_sitting)),
        total_downstream_standing=isempty(chain_standing) ? 0 : sum(length.(chain_standing)),
        n_generations_sitting=length(chain_sitting),
        n_generations_standing=length(chain_standing)
    )
end