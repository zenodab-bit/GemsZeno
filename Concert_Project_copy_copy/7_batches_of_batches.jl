## === Concert_Config.jl ===
## Shared configuration — included by all three simulation files.
## Edit values here; they apply to whichever mode you run.

# --- Concert Settings ---
concert_date        = 1
const concert_days_range  = 1:1:100          # used only in BOB mode

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
const n_simulations = 100

# --- Derived ---
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total
const age_order = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

## === Concert_Simulation_BOB.jl ===
## Runs a batch of batches across a range of concert days.
## After this, run Concert_Analysis.jl.

const run_mode = :batch_of_batches

concert_date = 1  # not const — changes each iteration


include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Storage ===
infected_distributions  = Dict{Int, Vector{Float64}}()
summary_by_day          = Dict{Int, NamedTuple}()
concert_metrics_by_day  = Dict{Int, NamedTuple}()
per_day_tick_general    = Dict{Int, Dict{String, Vector{Vector{Float64}}}}()
per_day_tick_settings   = Dict{Int, Dict{Char, Vector{Vector{Float64}}}}()

for day in concert_days_range
    infected_distributions[day] = Float64[]
end




## === Run Batch of Batches ===
for day in concert_days_range
    println("\n=== Concert day $day of $(last(concert_days_range)) ===")

    global concert_date = day
    infected_at_concert_v = Float64[]

    day_infected_at_concert_v = Float64[]
    day_susceptible_cg_v      = Float64[]
    day_infectious_cg_v       = Float64[]
    day_infectious_pop_v      = Float64[]

    all_tick_cases_general_exposed    = Vector{Vector{Float64}}()
    all_tick_cases_general_infectious = Vector{Vector{Float64}}()
    all_tick_cases_general_recovered  = Vector{Vector{Float64}}()
    all_tick_cases_general_dead       = Vector{Vector{Float64}}()
    all_cumulative_infections         = Vector{Vector{Float64}}()
    all_cumulative_recoveries         = Vector{Vector{Float64}}()
    all_cumulative_deaths             = Vector{Vector{Float64}}()
    all_tick_cases                    = Dict{Char, Vector{Vector{Float64}}}()

    for i in 1:n_simulations
        sim = Simulation(
            configfile   = "Concert_Project_copy/toml/config_concert_covid.toml",
            population   = "Concert_Project_copy/Datastorage/people_Saalekreis_concert.jld2",
            settingsfile = "Concert_Project_copy/Datastorage/settings_Saalekreis.jld2",
            global_setting_contacts = ConcertContacts(),
            label = "Concert simulation day $day run $i"
        )

        cl = CustomLogger(concert_day_stats = concert_infectious)
        customlogger!(sim, cl)
        run!(sim)

        rd = ResultData(sim; style = "ConcertRD")

        sitting_rate = sim.pathogen.transmission_function.sitting_rate

        inf_logger         = dataframe(infectionlogger(sim))
        global_cases_count = 0
        for row in eachrow(inf_logger)
            if row.tick == concert_date && row.setting_type == 'g'
                global_cases_count += 1
            end
        end
        push!(infected_at_concert_v,     global_cases_count)
        push!(day_infected_at_concert_v, global_cases_count)

        # --- Concert population metrics ---
        concertgoer_ids          = Set(j.id for j in sim.population.individuals if j.occupation == 1 || j.occupation == 2)
        infected_before_ids      = Set{Int32}()
        currently_infectious_ids = Set{Int32}()
        same_day_other_ids       = Set{Int32}()

        for row in eachrow(inf_logger)
            if row.tick < concert_date
                push!(infected_before_ids, row.id_b)
                if row.infectiousness_onset <= concert_date &&
                   (row.recovery > concert_date || row.recovery == -1) &&
                   (row.death    > concert_date || row.death    == -1)
                    push!(currently_infectious_ids, row.id_b)
                end
            elseif row.tick == concert_date && row.setting_type != 'g'
                push!(same_day_other_ids, row.id_b)
            end
        end

        not_susceptible_ids = union(infected_before_ids, same_day_other_ids)
        susceptible_ids     = setdiff(concertgoer_ids, not_susceptible_ids)

        push!(day_susceptible_cg_v, length(susceptible_ids))
        push!(day_infectious_cg_v,  length(intersect(currently_infectious_ids, concertgoer_ids)))
        push!(day_infectious_pop_v, length(currently_infectious_ids))

        # --- Per-tick data ---
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

    infected_distributions[day] = infected_at_concert_v
    summary_by_day[day] = (
        mean   = mean(infected_at_concert_v),
        std    = std(infected_at_concert_v),
        cv     = std(infected_at_concert_v) / max(mean(infected_at_concert_v), 1) * 100,
        min    = minimum(infected_at_concert_v),
        p25    = quantile(infected_at_concert_v, 0.25),
        median = median(infected_at_concert_v),
        p75    = quantile(infected_at_concert_v, 0.75),
        p90    = quantile(infected_at_concert_v, 0.90),
        p95    = quantile(infected_at_concert_v, 0.95),
        max    = maximum(infected_at_concert_v)
    )
    concert_metrics_by_day[day] = (
        infected_at_concert_mean = mean(day_infected_at_concert_v),
        infected_at_concert_std  = std(day_infected_at_concert_v),
        susceptible_cg_mean      = mean(day_susceptible_cg_v),
        susceptible_cg_std       = std(day_susceptible_cg_v),
        infectious_cg_mean       = mean(day_infectious_cg_v),
        infectious_cg_std        = std(day_infectious_cg_v),
        infectious_pop_mean      = mean(day_infectious_pop_v),
        infectious_pop_std       = std(day_infectious_pop_v)
    )
    per_day_tick_general[day] = Dict(
        "exposed"               => all_tick_cases_general_exposed,
        "infectious"            => all_tick_cases_general_infectious,
        "recovered"             => all_tick_cases_general_recovered,
        "dead"                  => all_tick_cases_general_dead,
        "cumulative_infections" => all_cumulative_infections,
        "cumulative_recoveries" => all_cumulative_recoveries,
        "cumulative_deaths"     => all_cumulative_deaths
    )
    per_day_tick_settings[day] = all_tick_cases

    println("  Mean infected at concert: $(round(mean(infected_at_concert_v), digits=1))  Std: $(round(std(infected_at_concert_v), digits=1))")
end

println("\nBOB complete — run Concert_Analysis.jl to generate metrics and plots.")

include("8_analysis.jl")