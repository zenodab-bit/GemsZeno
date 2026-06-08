## === Concert_Config.jl ===
## Shared configuration — included by all three simulation files.
## Edit values here; they apply to whichever mode you run.

# --- Concert Settings ---
const concert_date        = 25      # used only in BOB mode

const event_size_total         = 1000
const concert_groups_number    = [583, 576]
const concert_groups_percentage = [1, 0]
const concert_attendance_levels = [1, 2]
const concert_groups_number_true = true

# --- Demographic Settings ---
const sex_groups_percentage = [0.5, 0.5]
const sex_levels            = [1, 2]
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

# --- Batch Settings ---
const n_simulations = 3

# --- Derived ---
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total
const age_order = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

## === Concert_Simulation_Batch.jl ===
## Runs a batch of simulations for a single concert day.
## After this, run Concert_Analysis.jl.

const run_mode = :batch

include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Storage ===
total_infected_v             = Float64[]
attack_rate_v                = Float64[]
r0_v                         = Float64[]
infectious_population_v      = Float64[]
infectious_concertgoers_v    = Float64[]
expected_infectious_simple_v = Float64[]
infected_at_concert_v        = Float64[]
susceptible_before_v         = Float64[]
exposed_before_v             = Float64[]
same_day_other_v             = Float64[]
infectious_before_v          = Float64[]
recovered_before_v           = Float64[]
dead_before_v                = Float64[]
infection_rate_v             = Float64[]
expected_concert_infections_v = Float64[]
observed_concert_infections_v = Float64[]

obs_inf_by_age      = Dict(age => Float64[] for age in age_order)
obs_sus_by_age      = Dict(age => Float64[] for age in age_order)
exp_inf_by_age      = Dict(age => Float64[] for age in age_order)
exp_sus_by_age      = Dict(age => Float64[] for age in age_order)
pop_inf_rate_by_age = Dict(age => Float64[] for age in age_order)
pop_sus_rate_by_age = Dict(age => Float64[] for age in age_order)

all_tick_cases_general_exposed    = Vector{Vector{Float64}}()
all_tick_cases_general_infectious = Vector{Vector{Float64}}()
all_tick_cases_general_recovered  = Vector{Vector{Float64}}()
all_tick_cases_general_dead       = Vector{Vector{Float64}}()
all_cumulative_infections         = Vector{Vector{Float64}}()
all_cumulative_recoveries         = Vector{Vector{Float64}}()
all_cumulative_deaths             = Vector{Vector{Float64}}()
all_tick_cases                    = Dict{Char, Vector{Vector{Float64}}}()




## === Run Batch ===
for i in 1:n_simulations
    println("\n=== Running simulation $i of $n_simulations ===")

    sim = Simulation(
        configfile   = "Concert_Project/toml/config_concert_covid.toml",
        population   = "Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
        settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
        global_setting_contacts = ConcertContacts(),
        label = "Concert simulation $i"
    )

    cl = CustomLogger(concert_day_stats = concert_infectious)
    customlogger!(sim, cl)
    run!(sim)

    rd = ResultData(sim; style = "ConcertRD")

    sitting_rate = sim.pathogen.transmission_function.sitting_rate
    pop_size     = nrow(people)

    push!(total_infected_v, rd.data["sim_data"]["total_infections"])
    push!(attack_rate_v,    rd.data["sim_data"]["attack_rate"] * 100)
    push!(r0_v,             rd.data["sim_data"]["r0"])

    cl_data           = sim.customlogger.data
    infectious_in_pop = 0
    for row in eachrow(cl_data)
        if row.tick == concert_date
            stats = row.concert_day_stats
            push!(infectious_population_v,   stats[1])
            push!(infectious_concertgoers_v, stats[2])
            infectious_in_pop = stats[1]
            break
        end
    end
    push!(expected_infectious_simple_v, (infectious_in_pop / pop_size) * actual_event_size)

    concertgoer_ids             = Set(j.id for j in sim.population.individuals if j.occupation == 1 || j.occupation == 2)
    inf_logger                  = dataframe(infectionlogger(sim))
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
            if row.infectiousness_onset <= concert_date &&
               (row.recovery > concert_date || row.recovery == -1) &&
               (row.death    > concert_date || row.death    == -1)
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

    s_cg        = length(susceptible_ids)
    inf_cg      = length(intersect(currently_infectious_ids, concertgoer_ids))
    exp_cg      = length(intersect(exposed_before_concert_ids, concertgoer_ids))
    rec_cg      = length(intersect(recovered_ids, concertgoer_ids))
    dead_cg     = length(intersect(dead_ids, concertgoer_ids))
    same_day_cg = length(intersect(same_day_other_ids, concertgoer_ids))
    sus_inf_cg  = length(intersect(susceptible_ids, concert_infected_ids))

    push!(susceptible_before_v,  s_cg)
    push!(exposed_before_v,      exp_cg)
    push!(infectious_before_v,   inf_cg)
    push!(recovered_before_v,    rec_cg)
    push!(dead_before_v,         dead_cg)
    push!(same_day_other_v,      same_day_cg)
    push!(infected_at_concert_v, global_cases_count)
    push!(infection_rate_v,      sus_inf_cg / s_cg * 100)

    pop_size_by_age        = Dict(age => 0 for age in age_order)
    pop_infectious_by_age  = Dict(age => 0 for age in age_order)
    pop_susceptible_by_age = Dict(age => 0 for age in age_order)
    cg_size_by_age         = Dict(age => 0 for age in age_order)
    cg_infectious_by_age   = Dict(age => 0 for age in age_order)
    cg_susceptible_by_age  = Dict(age => 0 for age in age_order)

    for j in sim.population.individuals
        age            = age_group_label(j.age)
        is_infectious  = j.id in currently_infectious_ids
        is_susceptible = !(j.id in not_susceptible_ids)
        pop_size_by_age[age] += 1
        is_infectious  && (pop_infectious_by_age[age]  += 1)
        is_susceptible && (pop_susceptible_by_age[age] += 1)
        if j.occupation == 1 || j.occupation == 2
            cg_size_by_age[age] += 1
            is_infectious  && (cg_infectious_by_age[age]  += 1)
            is_susceptible && (cg_susceptible_by_age[age] += 1)
        end
    end

    for age in age_order
        pop_inf_rate = pop_infectious_by_age[age]  / pop_size_by_age[age]
        pop_sus_rate = pop_susceptible_by_age[age] / pop_size_by_age[age]
        cg_size      = cg_size_by_age[age]
        push!(obs_inf_by_age[age],      cg_infectious_by_age[age])
        push!(obs_sus_by_age[age],      cg_susceptible_by_age[age])
        push!(exp_inf_by_age[age],      pop_inf_rate * cg_size)
        push!(exp_sus_by_age[age],      pop_sus_rate * cg_size)
        push!(pop_inf_rate_by_age[age], pop_inf_rate * 100)
        push!(pop_sus_rate_by_age[age], pop_sus_rate * 100)
    end

    exponent                    = inf_cg * mean_number_of_contacts_sitting * sitting_rate / (actual_event_size - 1)
    p_infected                  = 1 - exp(-exponent)
    expected_concert_infections = s_cg * p_infected
    push!(expected_concert_infections_v, expected_concert_infections)
    push!(observed_concert_infections_v, global_cases_count)

    tick_cases_sim = rd.data["dataframes"]["tick_cases"]
    push!(all_tick_cases_general_exposed,    Float64.(tick_cases_sim[!, "exposed_cnt"]))
    push!(all_tick_cases_general_infectious, Float64.(tick_cases_sim[!, "infectious_cnt"]))
    push!(all_tick_cases_general_recovered,  Float64.(tick_cases_sim[!, "recovered_cnt"]))
    push!(all_tick_cases_general_dead,       Float64.(tick_cases_sim[!, "dead_cnt"]))

    cum_df = rd.data["dataframes"]["cumulative_cases"]
    push!(all_cumulative_infections, Float64.(cum_df[!, "exposed_cum"]))
    push!(all_cumulative_recoveries, Float64.(cum_df[!, "recovered_cum"]))
    push!(all_cumulative_deaths,     Float64.(cum_df[!, "deaths_cum"]))

    tick_cases_concert = rd.data["dataframes"]["tick_cases_per_setting"]
    n_ticks = rd.data["sim_data"]["final_tick"]
    for setting in ['h', 'c', 'o', 'g', 'm']
        setting_rows = zeros(Float64, n_ticks)
        for row in eachrow(tick_cases_concert)
            row.setting_type == setting && (setting_rows[row.tick] = Float64(row.daily_cases))
        end
        if !haskey(all_tick_cases, setting)
            all_tick_cases[setting] = Vector{Vector{Float64}}()
        end
        push!(all_tick_cases[setting], setting_rows)
    end
end




## === Populate Shared Analysis Variables ===
per_day_tick_general = Dict(concert_date => Dict(
    "exposed"               => all_tick_cases_general_exposed,
    "infectious"            => all_tick_cases_general_infectious,
    "recovered"             => all_tick_cases_general_recovered,
    "dead"                  => all_tick_cases_general_dead,
    "cumulative_infections" => all_cumulative_infections,
    "cumulative_recoveries" => all_cumulative_recoveries,
    "cumulative_deaths"     => all_cumulative_deaths
))
per_day_tick_settings = Dict(concert_date => all_tick_cases)

println("\nBatch complete — run Concert_Analysis.jl to generate metrics and plots.")