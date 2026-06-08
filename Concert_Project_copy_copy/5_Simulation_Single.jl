## === Concert_Config.jl ===
## Shared configuration — included by all three simulation files.
## Edit values here; they apply to whichever mode you run.

# --- Concert Settings ---
const concert_date        = 25       # used only in BOB mode

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

# --- Derived ---
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total
const age_order = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

## === Concert_Simulation_Single.jl ===
## Runs a single simulation and populates shared analysis variables.
## After this, run Concert_Analysis.jl.

const run_mode = :single

include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Run Simulation ===
sim = Simulation(
    configfile   = "Concert_Project/toml/config_concert_covid.toml",
    population   = "Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
    global_setting_contacts = ConcertContacts(),
    label = "Concert simulation single"
)

cl = CustomLogger(concert_day_stats = concert_infectious)
customlogger!(sim, cl)
run!(sim)

rd = ResultData(sim; style = "ConcertRD")

sitting_rate  = sim.pathogen.transmission_function.sitting_rate
standing_rate = sim.pathogen.transmission_function.standing_rate
general_rate  = sim.pathogen.transmission_function.general_rate
pop_size      = nrow(people)




## === Populate Shared Analysis Variables ===

# --- Scalar sim metrics ---
single_total_infected  = rd.data["sim_data"]["total_infections"]
single_attack_rate     = rd.data["sim_data"]["attack_rate"] * 100
single_r0              = rd.data["sim_data"]["r0"]

# --- Infectious from custom logger ---
cl_data           = sim.customlogger.data
infectious_in_pop = 0
for row in eachrow(cl_data)
    if row.tick == concert_date
        stats = row.concert_day_stats
        global infectious_in_pop = stats[1]
        global single_infectious_pop_on_day = stats[1]
        global single_infectious_cg_on_day  = stats[2]
        break
    end
end
single_expected_infectious_simple = (infectious_in_pop / pop_size) * actual_event_size

# --- Concert population analysis ---
concertgoer_ids             = Set(i.id for i in sim.population.individuals if i.occupation == 1 || i.occupation == 2)
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

single_susceptible_cg    = length(susceptible_ids)
single_exposed_before_cg = length(intersect(exposed_before_concert_ids, concertgoer_ids))
single_same_day_cg       = length(intersect(same_day_other_ids, concertgoer_ids))
single_infectious_cg     = length(intersect(currently_infectious_ids, concertgoer_ids))
single_recovered_cg      = length(intersect(recovered_ids, concertgoer_ids))
single_dead_cg           = length(intersect(dead_ids, concertgoer_ids))

single_infected_at_concert    = global_cases_count
single_susceptible_infected   = length(intersect(susceptible_ids, concert_infected_ids))
single_susceptible_notinfected = single_susceptible_cg - single_susceptible_infected
single_infection_rate         = single_susceptible_infected / single_susceptible_cg * 100

# --- Age group analysis ---
pop_size_by_age        = Dict(age => 0 for age in age_order)
pop_infectious_by_age  = Dict(age => 0 for age in age_order)
pop_susceptible_by_age = Dict(age => 0 for age in age_order)
cg_size_by_age         = Dict(age => 0 for age in age_order)
cg_infectious_by_age   = Dict(age => 0 for age in age_order)
cg_susceptible_by_age  = Dict(age => 0 for age in age_order)

for i in sim.population.individuals
    age            = age_group_label(i.age)
    is_infectious  = i.id in currently_infectious_ids
    is_susceptible = !(i.id in not_susceptible_ids)
    pop_size_by_age[age] += 1
    is_infectious  && (pop_infectious_by_age[age]  += 1)
    is_susceptible && (pop_susceptible_by_age[age] += 1)
    if i.occupation == 1 || i.occupation == 2
        cg_size_by_age[age] += 1
        is_infectious  && (cg_infectious_by_age[age]  += 1)
        is_susceptible && (cg_susceptible_by_age[age] += 1)
    end
end

single_age_data = Dict(age => (
    pop_inf_rate = pop_infectious_by_age[age]  / pop_size_by_age[age],
    pop_sus_rate = pop_susceptible_by_age[age] / pop_size_by_age[age],
    cg_size      = cg_size_by_age[age],
    exp_inf      = pop_infectious_by_age[age]  / pop_size_by_age[age] * cg_size_by_age[age],
    obs_inf      = cg_infectious_by_age[age],
    exp_sus      = pop_susceptible_by_age[age] / pop_size_by_age[age] * cg_size_by_age[age],
    obs_sus      = cg_susceptible_by_age[age]
) for age in age_order)

single_exp_inf_total = sum(single_age_data[age].exp_inf for age in age_order)
single_exp_sus_total = sum(single_age_data[age].exp_sus for age in age_order)
single_var_inf_total = sum(single_age_data[age].cg_size * single_age_data[age].pop_inf_rate * (1 - single_age_data[age].pop_inf_rate) for age in age_order)
single_var_sus_total = sum(single_age_data[age].cg_size * single_age_data[age].pop_sus_rate * (1 - single_age_data[age].pop_sus_rate) for age in age_order)
single_std_inf       = sqrt(single_var_inf_total)
single_std_sus       = sqrt(single_var_sus_total)
single_z_inf         = (single_infectious_cg  - single_exp_inf_total) / single_std_inf
single_z_sus         = (single_susceptible_cg - single_exp_sus_total) / single_std_sus

# --- Expected vs observed at concert ---
single_exponent          = single_infectious_cg * mean_number_of_contacts_sitting * sitting_rate / (actual_event_size - 1)
single_p_infected        = 1 - exp(-single_exponent)
single_p_not_infected    = exp(-single_exponent)
single_exp_concert_inf   = single_susceptible_cg * single_p_infected
single_std_concert_inf   = sqrt(single_susceptible_cg * single_p_infected * single_p_not_infected)
single_z_concert         = (single_infected_at_concert - single_exp_concert_inf) / single_std_concert_inf

# --- Per-tick data for plots ---
# Wrapped in single-entry dicts so the analysis file can use the same structure as batch/BOB
per_day_tick_general = Dict(concert_date => Dict(
    "exposed"               => [Float64.(rd.data["dataframes"]["tick_cases"][!, "exposed_cnt"])],
    "infectious"            => [Float64.(rd.data["dataframes"]["tick_cases"][!, "infectious_cnt"])],
    "recovered"             => [Float64.(rd.data["dataframes"]["tick_cases"][!, "recovered_cnt"])],
    "dead"                  => [Float64.(rd.data["dataframes"]["tick_cases"][!, "dead_cnt"])],
    "cumulative_infections" => [Float64.(rd.data["dataframes"]["cumulative_cases"][!, "exposed_cum"])],
    "cumulative_recoveries" => [Float64.(rd.data["dataframes"]["cumulative_cases"][!, "recovered_cum"])],
    "cumulative_deaths"     => [Float64.(rd.data["dataframes"]["cumulative_cases"][!, "deaths_cum"])]
))

tick_cases_concert = rd.data["dataframes"]["tick_cases_per_setting"]
n_ticks            = rd.data["sim_data"]["final_tick"]
per_day_tick_settings = Dict(concert_date => Dict{Char, Vector{Vector{Float64}}}())
for setting in ['h', 'c', 'o', 'g', 'm']
    setting_rows = zeros(Float64, n_ticks)
    for row in eachrow(tick_cases_concert)
        row.setting_type == setting && (setting_rows[row.tick] = Float64(row.daily_cases))
    end
    per_day_tick_settings[concert_date][setting] = [setting_rows]
end

# gemsplot output (single-mode only)
single_rd = rd

println("\nSimulation complete — run Concert_Analysis.jl to generate metrics and plots.")