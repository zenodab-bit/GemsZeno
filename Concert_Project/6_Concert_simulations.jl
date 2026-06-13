## === Global Configuration ===
concert_date        = 1
concert_days_range  = 40:5:40
n_simulations       = 1

event_size_total          = 1000
concert_groups_percentage = [1, 0]
concert_groups_number     = [583, 576]
concert_attendance_levels = [1, 2]
concert_groups_number_true = true

sex_groups_percentage = [0.5, 0.5]
sex_levels            = [1, 2]
age_groups_percentage = [0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125]
age_groups            = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

mean_number_of_contacts_sitting  = 4
mean_number_of_contacts_standing = 12

# --- Derived ---
actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total

## === Concert_Simulation.jl ===
## Single simulation file handling all modes.


include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")
include("5_Concert_helpers.jl")




## === Storage ===
results_by_day = Dict{Int,Any}()




## === Simulation Loop ===
for day in concert_days_range
    global concert_date = day
    println("\n=== Concert day $day of $(last(concert_days_range)) ===")

    # --- Per-day storage (reset each day) ---
    results_vector = Vector{NamedTuple}()

    # general epidemic curves
    all_tick_cases_general_exposed = Vector{Vector{Float64}}()
    all_tick_cases_general_infectious = Vector{Vector{Float64}}()
    all_tick_cases_general_recovered = Vector{Vector{Float64}}()
    all_tick_cases_general_dead = Vector{Vector{Float64}}()

    # cumulative cases
    all_cumulative_infections = Vector{Vector{Float64}}()
    all_cumulative_recoveries = Vector{Vector{Float64}}()
    all_cumulative_deaths = Vector{Vector{Float64}}()

    # effective R
    all_effectiveR_rolling = Vector{Vector{Float64}}()
    all_effectiveR_inhh = Vector{Vector{Float64}}()
    all_effectiveR_outhh = Vector{Vector{Float64}}()

    # cases by setting
    all_tick_cases = Dict{Char,Vector{Vector{Float64}}}()

    # custom logger time series
    all_cl_total_infectious = Vector{Vector{Float64}}()
    all_cl_infectious_sitting = Vector{Vector{Float64}}()
    all_cl_infectious_standing = Vector{Vector{Float64}}()

    # scalar sim metrics
    total_infected_v = Float64[]
    attack_rate_v = Float64[]
    r0_v = Float64[]




    for i in 1:n_simulations
        println("  Day $day — simulation $i of $n_simulations")

        # --- Run simulation ---
        sim = Simulation(
            configfile="Concert_Project/toml/config_concert_covid.toml",
            population="Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
            settingsfile="Concert_Project/Datastorage/settings_Saalekreis.jld2",
            global_setting_contacts=ConcertContacts(),
            label="Concert simulation day $day run $i"
        )
        cl = CustomLogger(concert_day_stats=concert_infectious)
        customlogger!(sim, cl)
        run!(sim)
        rd = ResultData(sim; style="ConcertRD")

        sitting_rate = sim.pathogen.transmission_function.sitting_rate
        standing_rate = sim.pathogen.transmission_function.standing_rate

        # --- Scalar sim metrics ---
        push!(total_infected_v, rd.data["sim_data"]["total_infections"])
        push!(attack_rate_v, rd.data["sim_data"]["attack_rate"] * 100)
        push!(r0_v, rd.data["sim_data"]["r0"])

        # --- Custom logger time series ---
        cl_data = sim.customlogger.data
        cl_total_infectious_v = Float64[]
        cl_infectious_sitting_v = Float64[]
        cl_infectious_standing_v = Float64[]

        for row in eachrow(cl_data)
            stats = row.concert_day_stats
            push!(cl_total_infectious_v, Float64(stats.total_infectious))
            push!(cl_infectious_sitting_v, Float64(stats.infectious_sitting))
            push!(cl_infectious_standing_v, Float64(stats.infectious_standing))
        end

        push!(all_cl_total_infectious, cl_total_infectious_v)
        push!(all_cl_infectious_sitting, cl_infectious_sitting_v)
        push!(all_cl_infectious_standing, cl_infectious_standing_v)

        # --- Concert population analysis ---
        result = analyze_concert_population(
            sim, concert_date, sitting_rate, standing_rate,
            mean_number_of_contacts_sitting, mean_number_of_contacts_standing,
            actual_event_size
        )
        push!(results_vector, result)

        # --- Per-tick general data ---
        tick_cases_sim = rd.data["dataframes"]["tick_cases"]
        push!(all_tick_cases_general_exposed, Float64.(tick_cases_sim[!, "exposed_cnt"]))
        push!(all_tick_cases_general_infectious, Float64.(tick_cases_sim[!, "infectious_cnt"]))
        push!(all_tick_cases_general_recovered, Float64.(tick_cases_sim[!, "recovered_cnt"]))
        push!(all_tick_cases_general_dead, Float64.(tick_cases_sim[!, "dead_cnt"]))

        # --- Cumulative cases ---
        cum_df = rd.data["dataframes"]["cumulative_cases"]
        push!(all_cumulative_infections, Float64.(cum_df[!, "exposed_cum"]))
        push!(all_cumulative_recoveries, Float64.(cum_df[!, "recovered_cum"]))
        push!(all_cumulative_deaths, Float64.(cum_df[!, "deaths_cum"]))

        # --- Effective R ---
        eff_df = rd.data["dataframes"]["effectiveR"]
        push!(all_effectiveR_rolling, Float64.(eff_df[!, "rolling_R"]))
        push!(all_effectiveR_inhh, Float64.(eff_df[!, "rolling_in_hh_R"]))
        push!(all_effectiveR_outhh, Float64.(eff_df[!, "rolling_out_hh_R"]))

        # --- Per-tick setting data ---
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




    # --- Pack everything for this day ---
    results_by_day[day] = (
        # aggregated concert population metrics
        concert=aggregate_concert_results(results_vector),
        concert_raw = results_vector,

        # epidemic curve time series
        timeseries=Dict(
            "exposed" => all_tick_cases_general_exposed,
            "infectious" => all_tick_cases_general_infectious,
            "recovered" => all_tick_cases_general_recovered,
            "dead" => all_tick_cases_general_dead,
            "cumulative_infections" => all_cumulative_infections,
            "cumulative_recoveries" => all_cumulative_recoveries,
            "cumulative_deaths" => all_cumulative_deaths,
            "effectiveR_rolling" => all_effectiveR_rolling,
            "effectiveR_inhh" => all_effectiveR_inhh,
            "effectiveR_outhh" => all_effectiveR_outhh
        ),

        # cases by setting
        settings=all_tick_cases,

        # custom logger time series (stock values per tick)
        cl_timeseries=Dict(
            "total_infectious" => all_cl_total_infectious,
            "infectious_sitting" => all_cl_infectious_sitting,
            "infectious_standing" => all_cl_infectious_standing
        ),

        # scalar epidemic metrics
        sim_metrics=(
            total_infected=total_infected_v,
            attack_rate=attack_rate_v,
            r0=r0_v
        )
    )

    println("  Day $day complete.")
end

println("\nSimulation complete — run Concert_Analysis.jl to generate metrics and plots.")