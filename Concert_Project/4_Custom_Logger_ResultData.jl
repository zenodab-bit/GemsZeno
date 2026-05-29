## === Custom Result Data Style ===
mutable struct ConcertRD <: ResultDataStyle
    data::Dict{String, Any}
    ConcertRD(pP::PostProcessor) = new(Dict(
        "sim_data" => Dict(
            "label"              => label(simulation(pP)),
            "r0"                 => r0(pP),
            "initial_infections" => nrow(infectionsDF(pP)) - nrow(sim_infectionsDF(pP)),
            "total_infections"   => nrow(sim_infectionsDF(pP)),
            "attack_rate"        => attack_rate(pP),
            "final_tick"         => tick(simulation(pP)),
            "tick_unit"          => "day"
        ),
        "dataframes" => Dict(
            "tick_cases"             => tick_cases(pP),
            "tick_cases_per_setting" => tick_cases_per_setting(pP),
            "cumulative_cases"       => cumulative_cases(pP),
            "effectiveR"             => effectiveR(pP)
        )
    ))
end




## === Custom Logger ===
function concert_infectious(sim)
    tick(sim) == concert_date || return (0, 0, 0, 0)
    total_infectious = 0
    infectious_concertgoers = 0
    total_susceptible = 0
    susceptible_concertgoers = 0
    for i in sim.population.individuals
        if i.infectious == true
            total_infectious += 1
            if i.occupation == 1 || i.occupation == 2
                infectious_concertgoers += 1
            end
        end
        if i.number_of_infections == 0 && i.dead == false
            total_susceptible += 1
            if i.occupation == 1 || i.occupation == 2
                susceptible_concertgoers += 1
            end
        end
    end
    return total_infectious, infectious_concertgoers, total_susceptible, susceptible_concertgoers
end