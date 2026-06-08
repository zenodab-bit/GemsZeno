## === Custom Result Data Style ===
# Define a new mutable struct "ConcertRD" inheriting from "ResultDataStyle" to store simulations results
mutable struct ConcertRD <: ResultDataStyle
    # store the data as a nested dictionary
    data::Dict{String, Any} 
    # Initialize the data field with simulation metrics and Dataframes
    ConcertRD(pP::PostProcessor) = new(Dict(
        #list of summary statistics for the simulation
        "sim_data" => Dict(
            "label"              => label(simulation(pP)),                                  # simulation label/identifier
            "r0"                 => r0(pP),                                                 # basic reproduction number
            "initial_infections" => nrow(infectionsDF(pP)) - nrow(sim_infectionsDF(pP)),    # infections before simulation
            "total_infections"   => nrow(sim_infectionsDF(pP)),                             # infections at the simulation
            "attack_rate"        => attack_rate(pP),                                        # proportion of population infected
            "final_tick"         => tick(simulation(pP)),                                   # final time step of the simulation
            "tick_unit"          => "day"                                                   # time unit for ticks (day/hours/months or whatever)
        ),
        "dataframes" => Dict(                                                               # dataframe containing time-series results
            "tick_cases"             => tick_cases(pP),                                     # cases per time step
            "tick_cases_per_setting" => tick_cases_per_setting(pP),                         # cases per setting per time step
            "cumulative_cases"       => cumulative_cases(pP),                               # cumulative cases over time
            "effectiveR"             => effectiveR(pP)                                      # effective reproduction number over time
        )
    ))
end




## === Custom Logger ===
# logs the number of infectious and susceptible individuals at the concert date.
# returns a tuple
function concert_infectious(sim)
    # skip if not the concert date
    tick(sim) == concert_date || return (0, 0, 0, 0)

    # initialize counters
    total_infectious = 0
    infectious_concertgoers = 0
    total_susceptible = 0
    susceptible_concertgoers = 0

    # iterate over all individuals in the simulation
    for i in sim.population.individuals
        # count infectious
        if i.infectious == true
            total_infectious += 1
            # count infectious concertgoers
            if i.occupation == 1 || i.occupation == 2
                infectious_concertgoers += 1
            end
        end
        # count susceptible
        if i.number_of_infections == 0 && i.dead == false
            total_susceptible += 1
            # count susceptible concertgoers
            if i.occupation == 1 || i.occupation == 2
                susceptible_concertgoers += 1
            end
        end
    end
    return total_infectious, infectious_concertgoers, total_susceptible, susceptible_concertgoers
end



## END
println("\nEND CUSTOM LOGGER & RESULT DATA 4")