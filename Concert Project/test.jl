##
##
using GEMS, DataFrames, StatsBase, Plots

inds = individuals(sim_concert)

# infectious at day 15
infectious_15 = filter(ind -> GEMS.is_infectious(ind, Int16(15)), inds)

# map id → age group
id_to_agegrp = Dict(people.id .=> people.age_group)

infected_age_groups = [id_to_agegrp[ind.id] for ind in infectious_15]

# counts
counts = countmap(infected_age_groups)

df = DataFrame(
    age_group = collect(keys(counts)),
    count = collect(values(counts))
)

sort!(df, :age_group)

bar(df.age_group, df.count,
    xlabel="Age group",
    ylabel="Infectious (day 15)",
    legend=false,
    rotation=45
)




##
age_counts = countmap(people.age_group)

df = DataFrame(
    age_group = collect(keys(age_counts)),
    count = collect(values(age_counts))
)

sort!(df, :age_group)

bar(df.age_group, df.count,
    xlabel="Age group",
    ylabel="Total individuals",
    legend=false,
    rotation=45
)



##

inds = individuals(sim_concert)

infectious_global_tick15 = count(ind ->
    GEMS.is_infectious(ind, Int16(15)),
    inds
)

println("Infectious (global) at tick 15: ", infectious_global_tick15)

##
infectious_concert_tick15 = count(ind ->
    (ind.occupation == 1 || ind.occupation == 2) &&
    GEMS.is_infectious(ind, Int16(15)),
    inds
)

println("Infectious (concert participants) at tick 15: ", infectious_concert_tick15)



infectious_sitting = count(ind ->

    ind.occupation == 1 &&
    GEMS.is_infectious(ind, Int16(15)),
    inds
)

infectious_standing = count(ind ->
    ind.occupation == 2 &&
    GEMS.is_infectious(ind, Int16(15)),
    inds
)

println("Sitting infectious: ", infectious_sitting)
println("Standing infectious: ", infectious_standing)