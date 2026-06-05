## === Global Configuration ===
# --- Concert Settings ---
const concert_date = 25
const event_size_total = 0
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

# --- Batch Settings ---
const n_simulations = 10




## === Derived Constants ===
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total




## === Plot Label ===
concert_label = concert_groups_number_true && sum(concert_groups_number) == 0 ? "no_concert" : "concert_day_$(concert_date)"




## === Include Custom Modules ===
include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Storage Vectors ===
# scalar metrics
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

# expected vs observed infections at concert
expected_concert_infections_v = Float64[]
observed_concert_infections_v = Float64[]

# age group storage
age_order = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]
obs_inf_by_age      = Dict(age => Float64[] for age in age_order)
obs_sus_by_age      = Dict(age => Float64[] for age in age_order)
exp_inf_by_age      = Dict(age => Float64[] for age in age_order)
exp_sus_by_age      = Dict(age => Float64[] for age in age_order)
pop_inf_rate_by_age = Dict(age => Float64[] for age in age_order)
pop_sus_rate_by_age = Dict(age => Float64[] for age in age_order)

# tick cases
all_tick_cases_general_exposed    = Vector{Vector{Float64}}()
all_tick_cases_general_infectious = Vector{Vector{Float64}}()
all_tick_cases_general_recovered  = Vector{Vector{Float64}}()
all_tick_cases_general_dead       = Vector{Vector{Float64}}()

# cumulative cases
all_cumulative_infections = Vector{Vector{Float64}}()
all_cumulative_recoveries = Vector{Vector{Float64}}()
all_cumulative_deaths     = Vector{Vector{Float64}}()

# effective R
all_effectiveR_rolling = Vector{Vector{Float64}}()
all_effectiveR_inhh    = Vector{Vector{Float64}}()
all_effectiveR_outhh   = Vector{Vector{Float64}}()

# cases by setting
all_tick_cases = Dict{Char, Vector{Vector{Float64}}}()




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

    # --- Metric 1: total infected, attack rate, R0 ---
    push!(total_infected_v, rd.data["sim_data"]["total_infections"])
    push!(attack_rate_v,    rd.data["sim_data"]["attack_rate"] * 100)
    push!(r0_v,             rd.data["sim_data"]["r0"])

    # --- Metrics 2, 3: from custom logger ---
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

    # --- Concert population analysis ---
    concertgoer_ids = Set(j.id for j in sim.population.individuals if j.occupation == 1 || j.occupation == 2)
    inf_logger      = dataframe(infectionlogger(sim))

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

    # --- Age group analysis ---
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
        if is_infectious
            pop_infectious_by_age[age] += 1
        end
        if is_susceptible
            pop_susceptible_by_age[age] += 1
        end
        if j.occupation == 1 || j.occupation == 2
            cg_size_by_age[age] += 1
            if is_infectious
                cg_infectious_by_age[age] += 1
            end
            if is_susceptible
                cg_susceptible_by_age[age] += 1
            end
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

    # --- Expected vs observed infections at concert ---
    exponent                    = inf_cg * mean_number_of_contacts_sitting * sitting_rate / (actual_event_size - 1)
    p_infected                  = 1 - exp(-exponent)
    expected_concert_infections = s_cg * p_infected
    push!(expected_concert_infections_v, expected_concert_infections)
    push!(observed_concert_infections_v, global_cases_count)

    # --- Per-tick data for plots ---
    tick_cases_sim = rd.data["dataframes"]["tick_cases"]
    push!(all_tick_cases_general_exposed,    Float64.(tick_cases_sim[!, "exposed_cnt"]))
    push!(all_tick_cases_general_infectious, Float64.(tick_cases_sim[!, "infectious_cnt"]))
    push!(all_tick_cases_general_recovered,  Float64.(tick_cases_sim[!, "recovered_cnt"]))
    push!(all_tick_cases_general_dead,       Float64.(tick_cases_sim[!, "dead_cnt"]))

    cum_df = rd.data["dataframes"]["cumulative_cases"]
    push!(all_cumulative_infections, Float64.(cum_df[!, "exposed_cum"]))
    push!(all_cumulative_recoveries, Float64.(cum_df[!, "recovered_cum"]))
    push!(all_cumulative_deaths,     Float64.(cum_df[!, "deaths_cum"]))

    eff_df = rd.data["dataframes"]["effectiveR"]
    push!(all_effectiveR_rolling, Float64.(eff_df[!, "rolling_R"]))
    push!(all_effectiveR_inhh,    Float64.(eff_df[!, "rolling_in_hh_R"]))
    push!(all_effectiveR_outhh,   Float64.(eff_df[!, "rolling_out_hh_R"]))

    tick_cases_concert = rd.data["dataframes"]["tick_cases_per_setting"]
    n_ticks = rd.data["sim_data"]["final_tick"]
    for setting in ['h', 'c', 'o', 'g', 'm']
        setting_rows = zeros(Float64, n_ticks)
        for row in eachrow(tick_cases_concert)
            if row.setting_type == setting
                setting_rows[row.tick] = Float64(row.daily_cases)
            end
        end
        if !haskey(all_tick_cases, setting)
            all_tick_cases[setting] = Vector{Vector{Float64}}()
        end
        push!(all_tick_cases[setting], setting_rows)
    end
end




## === Summary Statistics ===
function summary_stats(v)
    return (
        mean   = mean(v),
        std    = std(v),
        cv     = std(v) / mean(v) * 100,
        min    = minimum(v),
        p25    = quantile(v, 0.25),
        median = median(v),
        p75    = quantile(v, 0.75),
        p90    = quantile(v, 0.90),
        p95    = quantile(v, 0.95),
        max    = maximum(v)
    )
end

println("\n=== Summary Statistics ===")

s = summary_stats(total_infected_v)
println("\nTotal infected in population:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(attack_rate_v)
println("\nAttack rate:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(r0_v)
println("\nR0:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(infectious_population_v)
println("\nInfectious in population on concert day:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(infectious_concertgoers_v)
println("\nInfectious concert-goers on concert day:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(expected_infectious_simple_v)
println("\nExpected infectious concert-goers (simple):")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(infected_at_concert_v)
println("\nPeople infected at the concert:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

println("\n=== Before Concert ===")

s = summary_stats(susceptible_before_v)
println("\nSusceptible at concert:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(exposed_before_v)
println("\nExposed before concert day:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(same_day_other_v)
println("\nExposed same day before concert:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(infectious_before_v)
println("\nInfectious:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(recovered_before_v)
println("\nRecovered/immune:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")

s = summary_stats(dead_before_v)
println("\nDead:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")
println("\n=== After Concert ===")

s = summary_stats(infection_rate_v)
println("\nInfection rate among susceptible:")
println("  Mean:   $(round(s.mean, digits=1))  Std: $(round(s.std, digits=1))  CV: $(round(s.cv, digits=1))%")
println("  Min:    $(round(s.min, digits=1))  P25: $(round(s.p25, digits=1))  Median: $(round(s.median, digits=1))  P75: $(round(s.p75, digits=1))  P90: $(round(s.p90, digits=1))  P95: $(round(s.p95, digits=1))  Max: $(round(s.max, digits=1))")




## === Expected vs Observed by Age Group ===
println("\n=== Expected vs Observed by Age Group ===")
println(rpad("Age group", 10), " | ",
        rpad("Pop inf%", 14), " | ",
        rpad("Pop sus%", 14), " | ",
        rpad("Exp inf", 14), " | ",
        rpad("Obs inf", 14), " | ",
        rpad("Exp sus", 14), " | ",
        "Obs sus")
println("-"^105)

total_exp_inf_v = zeros(n_simulations)
total_obs_inf_v = zeros(n_simulations)
total_exp_sus_v = zeros(n_simulations)
total_obs_sus_v = zeros(n_simulations)

for age in age_order
    pop_inf_m = mean(pop_inf_rate_by_age[age])
    pop_inf_s = std(pop_inf_rate_by_age[age])
    pop_sus_m = mean(pop_sus_rate_by_age[age])
    pop_sus_s = std(pop_sus_rate_by_age[age])
    exp_inf_m = mean(exp_inf_by_age[age])
    exp_inf_s = std(exp_inf_by_age[age])
    obs_inf_m = mean(obs_inf_by_age[age])
    obs_inf_s = std(obs_inf_by_age[age])
    exp_sus_m = mean(exp_sus_by_age[age])
    exp_sus_s = std(exp_sus_by_age[age])
    obs_sus_m = mean(obs_sus_by_age[age])
    obs_sus_s = std(obs_sus_by_age[age])

    for j in 1:n_simulations
        total_exp_inf_v[j] += exp_inf_by_age[age][j]
        total_obs_inf_v[j] += obs_inf_by_age[age][j]
        total_exp_sus_v[j] += exp_sus_by_age[age][j]
        total_obs_sus_v[j] += obs_sus_by_age[age][j]
    end

    println(rpad(age, 10), " | ",
            rpad("$(round(pop_inf_m, digits=1))±$(round(pop_inf_s, digits=1))", 14), " | ",
            rpad("$(round(pop_sus_m, digits=1))±$(round(pop_sus_s, digits=1))", 14), " | ",
            rpad("$(round(exp_inf_m, digits=1))±$(round(exp_inf_s, digits=1))", 14), " | ",
            rpad("$(round(obs_inf_m, digits=1))±$(round(obs_inf_s, digits=1))", 14), " | ",
            rpad("$(round(exp_sus_m, digits=1))±$(round(exp_sus_s, digits=1))", 14), " | ",
            "$(round(obs_sus_m, digits=1))±$(round(obs_sus_s, digits=1))")
end

println("-"^105)

total_exp_inf_mean = mean(total_exp_inf_v)
total_exp_inf_std  = std(total_exp_inf_v)
total_obs_inf_mean = mean(total_obs_inf_v)
total_obs_inf_std  = std(total_obs_inf_v)
total_exp_sus_mean = mean(total_exp_sus_v)
total_exp_sus_std  = std(total_exp_sus_v)
total_obs_sus_mean = mean(total_obs_sus_v)
total_obs_sus_std  = std(total_obs_sus_v)

z_infectious  = (total_obs_inf_mean - total_exp_inf_mean) / total_obs_inf_std
z_susceptible = (total_obs_sus_mean - total_exp_sus_mean) / total_obs_sus_std

println(rpad("Total", 10), " | ",
        rpad("", 14), " | ",
        rpad("", 14), " | ",
        rpad("$(round(total_exp_inf_mean, digits=1))±$(round(total_exp_inf_std, digits=1))", 14), " | ",
        rpad("$(round(total_obs_inf_mean, digits=1))±$(round(total_obs_inf_std, digits=1))", 14), " | ",
        rpad("$(round(total_exp_sus_mean, digits=1))±$(round(total_exp_sus_std, digits=1))", 14), " | ",
        "$(round(total_obs_sus_mean, digits=1))±$(round(total_obs_sus_std, digits=1))")
println("\nInfectious  - Z-score: $(round(z_infectious,  digits=2))")
println("Susceptible - Z-score: $(round(z_susceptible, digits=2))")
println("Expected infectious (simple estimate): $(round(mean(expected_infectious_simple_v), digits=1)) ± $(round(std(expected_infectious_simple_v), digits=1))")
println("Expected infectious (age-adjusted):    $(round(total_exp_inf_mean, digits=1)) ± $(round(total_exp_inf_std, digits=1))")
println("Observed infectious:                   $(round(total_obs_inf_mean, digits=1)) ± $(round(total_obs_inf_std, digits=1))")




## === Expected vs Observed infections at concert ===
exp_mean  = mean(expected_concert_infections_v)
exp_std   = std(expected_concert_infections_v)
obs_mean  = mean(observed_concert_infections_v)
obs_std   = std(observed_concert_infections_v)
z_concert = (obs_mean - exp_mean) / obs_std

println("\n=== Expected vs Observed infections at concert ===")
println("Expected infections: $(round(exp_mean, digits=1)) ± $(round(exp_std, digits=1))")
println("Observed infections: $(round(obs_mean, digits=1)) ± $(round(obs_std, digits=1))")
println("Z-score:             $(round(z_concert, digits=2))")




## === Helper: shaded series ===
function shaded_series!(p, series_list, colors, labels)
    for (series, color, label) in zip(series_list, colors, labels)
        mat = hcat(series...)
        avg = mean(mat, dims=2)[:]
        lo  = minimum(mat, dims=2)[:]
        hi  = maximum(mat, dims=2)[:]
        plot!(p, 1:length(avg), avg,
            ribbon    = (avg .- lo, hi .- avg),
            fillalpha = 0.2,
            label     = label,
            color     = color,
            linewidth = 2
        )
    end
end




## === Plot 1: General (Tick Cases, Cumulative Cases, Effective R) ===
using StatsPlots
p1 = plot(title = "Cases per Day", xlabel = "Day", ylabel = "Individuals", dpi = 300)
shaded_series!(p1,
    [all_tick_cases_general_exposed, all_tick_cases_general_infectious, all_tick_cases_general_recovered, all_tick_cases_general_dead],
    [:blue, :orange, :green, :black],
    ["Exposed", "Became Infectious", "Recovered", "Died"]
)

p2 = plot(title = "Cumulative Cases", xlabel = "Days", ylabel = "Individuals", dpi = 300)
shaded_series!(p2,
    [all_cumulative_infections, all_cumulative_recoveries, all_cumulative_deaths],
    [:blue, :orange, :black],
    ["Infections", "Recoveries", "Deaths"]
)

p3 = plot(title = "Effective Reproduction Number", xlabel = "Days", ylabel = "Effective R", dpi = 300)
shaded_series!(p3,
    [all_effectiveR_rolling, all_effectiveR_inhh, all_effectiveR_outhh],
    [:blue, :orange, :green],
    ["(7-day Rolling) Effective R", "(7-day Rolling) Effective R (In Households)", "(7-day Rolling) Effective R (Outside Households)"]
)
hline!(p3, [1.0], linestyle = :dash, color = :red, label = "R=1")

gp = plot(p1, p2, p3,
    layout        = (3, 1),
    size          = (600, 800),
    titlefontsize = 10
)
png(gp, "Concert_Project/Plots/BOS_epidemic_curves_$(concert_label).png")




## === Plot 2: Cases by Setting ===
setting_colors = Dict('h' => :orange, 'c' => :red, 'o' => :purple, 'g' => :blue, 'm' => :brown)
setting_labels = Dict('h' => "Household", 'c' => "SchoolClass", 'o' => "Office", 'g' => "GlobalSetting", 'm' => "Municipality")
gp2 = plot(title = "Infections per Day by Setting", xlabel = "Day", ylabel = "Individuals", dpi = 300)
for setting in ['h', 'c', 'o', 'g', 'm']
    if haskey(all_tick_cases, setting) && !isempty(all_tick_cases[setting])
        mat = hcat(all_tick_cases[setting]...)
        avg = mean(mat, dims=2)[:]
        lo  = minimum(mat, dims=2)[:]
        hi  = maximum(mat, dims=2)[:]
        plot!(gp2, 1:length(avg), avg,
            ribbon    = (avg .- lo, hi .- avg),
            fillalpha = 0.3,
            label     = setting_labels[setting],
            color     = setting_colors[setting],
            linewidth = 2
        )
    end
end
png(gp2, "Concert_Project/Plots/BOS_setting_infections_$(concert_label).png")




## === Plot 3: Boxplot infected at concert ===
gp3 = boxplot(
    ["Infected at concert"],
    [infected_at_concert_v],
    title     = "Distribution of Infections at Concert",
    ylabel    = "Number of Infections",
    legend    = false,
    dpi       = 300,
    color     = :blue,
    fillalpha = 0.5
)
png(gp3, "Concert_Project/Plots/BOS_infections_at_concert_boxplot_$(concert_label).png")

## END
println("\nEND SIMULATION 6 BATCHES")