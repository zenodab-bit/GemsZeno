## === Global Configuration ===
# --- Concert Settings ---
const concert_date = 35
const event_size_total = 1000
const concert_groups_percentage = [1, 0]
const concert_groups_number = [583, 576]
const concert_attendance_levels = [1, 2]
const concert_groups_number_true = true

# --- Demographic Settings ---
const sex_groups_percentage = [0.5, 0.5]
const sex_levels = [1, 2]
const age_groups_percentage = [
    0.125,  # Under 18
    0.125,  # 18-25
    0.125,  # 26-30
    0.125,  # 31-35
    0.125,  # 36-40
    0.125,  # 41-45
    0.125,  # 46-50
    0.125   # 50 and over
]
const age_groups = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

# --- Contact Settings ---
const mean_number_of_contacts_sitting  = 4
const mean_number_of_contacts_standing = 12




## === Derived Constants ===
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total






## === Plot Label ===
concert_label = concert_groups_number_true && sum(concert_groups_number) == 0 ? "no_concert" : "concert_day_$(concert_date)"




## === Include Custom Modules ===
include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Run Simulation ===
sim_concert = Simulation(
    configfile = "Concert_Project/toml/config_concert_covid.toml",
    population = "Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
    global_setting_contacts = ConcertContacts(),
    label = "Concert simulation"
)

cl = CustomLogger(concert_day_stats = concert_infectious)
customlogger!(sim_concert, cl)

run!(sim_concert)

rd_concert = ResultData(sim_concert; style = "ConcertRD")

sitting_rate  = sim_concert.pathogen.transmission_function.sitting_rate
standing_rate = sim_concert.pathogen.transmission_function.standing_rate
general_rate  = sim_concert.pathogen.transmission_function.general_rate
pop_size      = nrow(people)




## === Plot: All Settings ===
gp = gemsplot(rd_concert)
png(gp,  "Concert_Project/Plots/General_$(concert_label).png")




## === Plot: Filtered Settings ===
tick_cases_concert = rd_concert.data["dataframes"]["tick_cases_per_setting"]
tick_cases_filtered = Vector{DataFrameRow}()
for row in eachrow(tick_cases_concert)
    if row.setting_type in ['h', 'c', 'o', 'g', 'm']
        push!(tick_cases_filtered, row)
    end
end
rd_concert.data["dataframes"]["tick_cases_per_setting"] = DataFrame(tick_cases_filtered)
gp1 = gemsplot(rd_concert, type = :TickCasesBySetting)
png(gp1, "Concert_Project/Plots/Cases_by_setting_$(concert_label).png")




## === Metric 1: Total infected in population ===
println("Total infected in population: ", rd_concert.data["sim_data"]["total_infections"])
println("Attack rate:                  ", round(rd_concert.data["sim_data"]["attack_rate"] * 100, digits=2), "%")
println("R0:                           ", round(rd_concert.data["sim_data"]["r0"], digits=2))




## === Metrics 2, 3: Infectious from custom logger ===
cl_data           = sim_concert.customlogger.data
infectious_in_pop = 0
for row in eachrow(cl_data)
    if row.tick == concert_date
        stats = row.concert_day_stats
        println("Tick $(row.tick) - Infectious in population:           ", stats[1])
        println("Tick $(row.tick) - Infectious concert-goers:           ", stats[2])
        infectious_in_pop = stats[1]
        break
    end
end

expected_infectious_cg_simple = (infectious_in_pop / pop_size) * actual_event_size
println("Expected infectious concert-goers (simple): ", round(expected_infectious_cg_simple, digits=1))




## === Concert Population Analysis ===
concertgoer_ids = Set(i.id for i in sim_concert.population.individuals if i.occupation == 1 || i.occupation == 2)
inf_logger      = dataframe(infectionlogger(sim_concert))

# build all sets from infection logger in a single pass
infected_before_concert_ids = Set{Int32}()
currently_infectious_ids    = Set{Int32}()
exposed_before_concert_ids  = Set{Int32}()
recovered_ids               = Set{Int32}()
dead_ids                    = Set{Int32}()
same_day_other_ids          = Set{Int32}()
concert_infected_ids        = Set{Int32}()
global_cases_count          = 0

for row in eachrow(inf_logger)
    if row.tick < concert_date
        push!(infected_before_concert_ids, row.id_b)
        if row.infectiousness_onset <= concert_date && (row.recovery > concert_date || row.recovery == -1) && (row.death > concert_date || row.death == -1)
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
            global_cases_count += 1
        end
    end
end

not_susceptible_ids = union(infected_before_concert_ids, same_day_other_ids)
susceptible_ids     = setdiff(concertgoer_ids, not_susceptible_ids)
susceptible_cg      = length(susceptible_ids)
exposed_before_cg   = length(intersect(exposed_before_concert_ids, concertgoer_ids))
same_day_cg         = length(intersect(same_day_other_ids, concertgoer_ids))
infectious_cg       = length(intersect(currently_infectious_ids, concertgoer_ids))
recovered_cg        = length(intersect(recovered_ids, concertgoer_ids))
dead_cg             = length(intersect(dead_ids, concertgoer_ids))

println("\n=== Before concert (tick ", concert_date, ") ===")
println("Susceptible at concert:           ", susceptible_cg)
println("Exposed before concert day:       ", exposed_before_cg)
println("Exposed same day before concert:  ", same_day_cg)
println("Infectious:                       ", infectious_cg)
println("Recovered/immune:                 ", recovered_cg)
println("Dead:                             ", dead_cg)
println("Total:                            ", susceptible_cg + exposed_before_cg + same_day_cg + infectious_cg + recovered_cg + dead_cg)




## === After concert ===
susceptible_infected_at_concert = length(intersect(susceptible_ids, concert_infected_ids))

println("\n=== After concert ===")
println("Infected at concert:              ", global_cases_count)
println("Of which were susceptible:        ", susceptible_infected_at_concert)
println("Susceptible not infected:         ", susceptible_cg - susceptible_infected_at_concert)
println("Infection rate among susceptible: ", round(susceptible_infected_at_concert / susceptible_cg * 100, digits = 1), "%")




## === Expected vs Observed by Age Group ===
age_order = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

pop_size_by_age        = Dict(age => 0 for age in age_order)
pop_infectious_by_age  = Dict(age => 0 for age in age_order)
pop_susceptible_by_age = Dict(age => 0 for age in age_order)
cg_size_by_age         = Dict(age => 0 for age in age_order)
cg_infectious_by_age   = Dict(age => 0 for age in age_order)
cg_susceptible_by_age  = Dict(age => 0 for age in age_order)

for i in sim_concert.population.individuals
    age            = age_group_label(i.age)
    is_infectious  = i.id in currently_infectious_ids
    is_susceptible = !(i.id in not_susceptible_ids)
    pop_size_by_age[age] += 1
    if is_infectious
        pop_infectious_by_age[age] += 1
    end
    if is_susceptible
        pop_susceptible_by_age[age] += 1
    end
    if i.occupation == 1 || i.occupation == 2
        cg_size_by_age[age] += 1
        if is_infectious
            cg_infectious_by_age[age] += 1
        end
        if is_susceptible
            cg_susceptible_by_age[age] += 1
        end
    end
end

expected_infectious_total  = 0.0
expected_susceptible_total = 0.0
var_infectious_total       = 0.0
var_susceptible_total      = 0.0

println("\n=== Expected vs Observed by Age Group ===")
println(rpad("Age group", 10), " | ",
        rpad("Pop inf%", 8), " | ",
        rpad("Pop sus%", 8), " | ",
        rpad("CG size", 7), " | ",
        rpad("Exp inf", 7), " | ",
        rpad("Obs inf", 7), " | ",
        rpad("Exp sus", 7), " | ",
        "Obs sus")
println("-"^80)

for age in age_order
    pop_inf_rate = pop_infectious_by_age[age]  / pop_size_by_age[age]
    pop_sus_rate = pop_susceptible_by_age[age] / pop_size_by_age[age]
    cg_size      = cg_size_by_age[age]
    exp_inf      = pop_inf_rate * cg_size
    exp_sus      = pop_sus_rate * cg_size

    expected_infectious_total  += exp_inf
    expected_susceptible_total += exp_sus
    var_infectious_total       += cg_size * pop_inf_rate * (1 - pop_inf_rate)
    var_susceptible_total      += cg_size * pop_sus_rate * (1 - pop_sus_rate)

    println(rpad(age, 10), " | ",
            rpad(round(pop_inf_rate * 100, digits=1), 8), " | ",
            rpad(round(pop_sus_rate * 100, digits=1), 8), " | ",
            rpad(cg_size, 7), " | ",
            rpad(round(exp_inf, digits=1), 7), " | ",
            rpad(cg_infectious_by_age[age], 7), " | ",
            rpad(round(exp_sus, digits=1), 7), " | ",
            cg_susceptible_by_age[age])
end

std_infectious  = sqrt(var_infectious_total)
std_susceptible = sqrt(var_susceptible_total)
z_infectious    = (infectious_cg  - expected_infectious_total)  / std_infectious
z_susceptible   = (susceptible_cg - expected_susceptible_total) / std_susceptible

println("-"^80)
println(rpad("Total", 10), " | ",
        rpad("", 8), " | ",
        rpad("", 8), " | ",
        rpad(actual_event_size, 7), " | ",
        rpad(round(expected_infectious_total,  digits=1), 7), " | ",
        rpad(infectious_cg, 7), " | ",
        rpad(round(expected_susceptible_total, digits=1), 7), " | ",
        susceptible_cg)
println("\nInfectious  - Std: $(round(std_infectious,  digits=1))  Z-score: $(round(z_infectious,  digits=2))")
println("Susceptible - Std: $(round(std_susceptible, digits=1))  Z-score: $(round(z_susceptible, digits=2))")
println("Expected infectious (simple estimate): $(round(expected_infectious_cg_simple, digits=1))")
println("Expected infectious (age-adjusted):    $(round(expected_infectious_total, digits=1))")
println("Observed infectious:                   $(infectious_cg)")




## === Expected vs Observed infections at concert ===
exponent                    = infectious_cg * mean_number_of_contacts_sitting * sitting_rate / (actual_event_size - 1)
p_infected                  = 1 - exp(-exponent)
p_not_infected              = exp(-exponent)
expected_concert_infections = susceptible_cg * p_infected
std_concert_infections      = sqrt(susceptible_cg * p_infected * p_not_infected)
z_concert_infections        = (global_cases_count - expected_concert_infections) / std_concert_infections

println("\n=== Expected vs Observed infections at concert ===")
println("Expected infections: ", round(expected_concert_infections, digits=1))
println("Observed infections: ", global_cases_count)
println("Std:                 ", round(std_concert_infections, digits=1))
println("Z-score:             ", round(z_concert_infections, digits=2))




## END
println("\nEND SIMULATION 5 SINGLE SIMULATION")