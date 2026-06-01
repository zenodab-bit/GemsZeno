## === Concert Population Analysis ===
concertgoer_ids = Set(i.id for i in sim_concert.population.individuals if i.occupation == 1 || i.occupation == 2)
inf_logger      = dataframe(infectionlogger(sim_concert))
population_size = nrow(people)

# build all sets from infection logger in a single pass
not_susceptible_ids      = Set{Int32}()
currently_infectious_ids = Set{Int32}()
recovered_ids            = Set{Int32}()
dead_ids                 = Set{Int32}()
concert_infected_ids     = Set{Int32}()
same_day_other_ids       = Set{Int32}()
global_cases_count       = 0

for row in eachrow(inf_logger)
    if row.tick < concert_date
        push!(not_susceptible_ids, row.id_b)
        if row.infectiousness_onset <= concert_date && (row.recovery > concert_date || row.recovery == -1)
            push!(currently_infectious_ids, row.id_b)
        end
        if row.recovery != -1 && row.recovery <= concert_date
            push!(recovered_ids, row.id_b)
        end
        if row.death != -1 && row.death < concert_date
            push!(dead_ids, row.id_b)
        end
    elseif row.tick == concert_date
        if row.setting_type != 'g'
            push!(not_susceptible_ids, row.id_b)
            push!(same_day_other_ids, row.id_b)
        end
        if row.setting_type == 'g'
            push!(concert_infected_ids, row.id_b)
            global_cases_count += 1
        end
    end
end

# calculate categories directly from individual fields
susceptible_start_of_day = length(setdiff(concertgoer_ids, not_susceptible_ids)) + 
                           length(intersect(same_day_other_ids, concertgoer_ids))
same_day_cg              = length(intersect(same_day_other_ids, concertgoer_ids))
truly_susceptible_cg     = susceptible_start_of_day - same_day_cg

# exposed before concert day: not infectious, currently infected (from individual fields)
exposed_cg = count(i -> (i.occupation == 1 || i.occupation == 2) &&
                        i.infectious == false &&
                        i.number_of_infections > 0 &&
                        !(i.id in currently_infectious_ids) &&
                        !(i.id in recovered_ids) &&
                        !(i.id in concert_infected_ids) &&
                        !(i.id in same_day_other_ids),
                   sim_concert.population.individuals)

infectious_cg = length(intersect(currently_infectious_ids, concertgoer_ids))
recovered_cg  = length(intersect(recovered_ids, concertgoer_ids))
dead_cg       = count(i -> (i.occupation == 1 || i.occupation == 2) && i.dead == true,
                      sim_concert.population.individuals)

println("\n=== Before concert (tick ", concert_date, ") ===")
println("Susceptible at concert:           ", truly_susceptible_cg)
println("Exposed before concert day:       ", exposed_cg)
println("Exposed same day before concert:  ", same_day_cg)
println("Infectious:                       ", infectious_cg)
println("Recovered/immune:                 ", recovered_cg)
println("Dead:                             ", dead_cg)
println("Total:                            ", truly_susceptible_cg + exposed_cg + same_day_cg + infectious_cg + recovered_cg + dead_cg)

##