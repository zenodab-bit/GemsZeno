## === Concert_Analysis.jl ===
## Run this after any of the three simulation files.
## Reads from shared variables populated by the simulation file.
## Sections: METRICS (printed + saved to txt), then PLOTS.

using StatsPlots




## =============================================================================
## === HELPERS =================================================================
## =============================================================================

function summary_stats(v)
    (
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

function fmt(x; digits=1)
    round(x, digits=digits)
end

function dist_row(label, v, io)
    s = summary_stats(v)
    println(io, "\n$label:")
    println(io, "  Mean: $(fmt(s.mean))  Std: $(fmt(s.std))  CV: $(fmt(s.cv))%")
    println(io, "  Min: $(fmt(s.min))  P25: $(fmt(s.p25))  Median: $(fmt(s.median))  P75: $(fmt(s.p75))  P90: $(fmt(s.p90))  P95: $(fmt(s.p95))  Max: $(fmt(s.max))")
end

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

function ribbon_data(series_list)
    mat = hcat(series_list...)
    avg = mean(mat, dims=2)[:]
    lo  = minimum(mat, dims=2)[:]
    hi  = maximum(mat, dims=2)[:]
    return avg, lo, hi
end

function grand_average_ribbon(key)
    all_avgs = Vector{Vector{Float64}}()
    for day in concert_days_range
        mat = hcat(per_day_tick_general[day][key]...)
        push!(all_avgs, mean(mat, dims=2)[:])
    end
    grand_mat = hcat(all_avgs...)
    return mean(grand_mat, dims=2)[:], minimum(grand_mat, dims=2)[:], maximum(grand_mat, dims=2)[:]
end

function grand_average_ribbon_setting(setting)
    all_avgs = Vector{Vector{Float64}}()
    for day in concert_days_range
        if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
            mat = hcat(per_day_tick_settings[day][setting]...)
            push!(all_avgs, mean(mat, dims=2)[:])
        end
    end
    isempty(all_avgs) && return Float64[], Float64[], Float64[]
    grand_mat = hcat(all_avgs...)
    return mean(grand_mat, dims=2)[:], minimum(grand_mat, dims=2)[:], maximum(grand_mat, dims=2)[:]
end

const setting_colors = Dict('h' => :orange, 'c' => :red, 'o' => :purple, 'g' => :blue, 'm' => :brown)
const setting_labels = Dict('h' => "Household", 'c' => "SchoolClass", 'o' => "Office", 'g' => "GlobalSetting", 'm' => "Municipality")
const setting_list   = ['h', 'c', 'o', 'g', 'm']




## =============================================================================
## === METRICS =================================================================
## =============================================================================

open("Concert_Project_copy/Results/concert_analysis_summary.txt", "w") do io

    println(io, "=== Concert Analysis Summary ===")
    println(io, "Mode: $run_mode")
    println(io, "")


    # -------------------------------------------------------------------------
    # SINGLE
    # -------------------------------------------------------------------------
    if run_mode == :single

        println(io, "=== Simulation Metrics ===")
        println(io, "Total infected in population: $single_total_infected")
        println(io, "Attack rate:                  $(fmt(single_attack_rate))%")
        println(io, "R0:                           $(fmt(single_r0))")
        println(io, "")
        println(io, "Infectious in population on concert day: $single_infectious_pop_on_day")
        println(io, "Infectious concert-goers on concert day: $single_infectious_cg_on_day")
        println(io, "Expected infectious concert-goers (simple): $(fmt(single_expected_infectious_simple))")

        println(io, "\n=== Before Concert (day $concert_date) ===")
        println(io, "Susceptible at concert:           $single_susceptible_cg")
        println(io, "Exposed before concert day:       $single_exposed_before_cg")
        println(io, "Exposed same day before concert:  $single_same_day_cg")
        println(io, "Infectious:                       $single_infectious_cg")
        println(io, "Recovered/immune:                 $single_recovered_cg")
        println(io, "Dead:                             $single_dead_cg")
        println(io, "Total:                            $(single_susceptible_cg + single_exposed_before_cg + single_same_day_cg + single_infectious_cg + single_recovered_cg + single_dead_cg)")

        println(io, "\n=== After Concert ===")
        println(io, "Infected at concert:              $single_infected_at_concert")
        println(io, "Of which were susceptible:        $single_susceptible_infected")
        println(io, "Susceptible not infected:         $single_susceptible_notinfected")
        println(io, "Infection rate among susceptible: $(fmt(single_infection_rate))%")

        println(io, "\n=== Expected vs Observed by Age Group ===")
        println(io, rpad("Age group", 10), " | ",
                rpad("Pop inf%", 8), " | ",
                rpad("Pop sus%", 8), " | ",
                rpad("CG size", 7), " | ",
                rpad("Exp inf", 7), " | ",
                rpad("Obs inf", 7), " | ",
                rpad("Exp sus", 7), " | ",
                "Obs sus")
        println(io, "-"^80)
        for age in age_order
            d = single_age_data[age]
            println(io, rpad(age, 10), " | ",
                    rpad(fmt(d.pop_inf_rate * 100), 8), " | ",
                    rpad(fmt(d.pop_sus_rate * 100), 8), " | ",
                    rpad(d.cg_size, 7), " | ",
                    rpad(fmt(d.exp_inf), 7), " | ",
                    rpad(d.obs_inf, 7), " | ",
                    rpad(fmt(d.exp_sus), 7), " | ",
                    d.obs_sus)
        end
        println(io, "-"^80)
        println(io, rpad("Total", 10), " | ",
                rpad("", 8), " | ",
                rpad("", 8), " | ",
                rpad(actual_event_size, 7), " | ",
                rpad(fmt(single_exp_inf_total), 7), " | ",
                rpad(single_infectious_cg, 7), " | ",
                rpad(fmt(single_exp_sus_total), 7), " | ",
                single_susceptible_cg)
        println(io, "\nInfectious  - Std: $(fmt(single_std_inf))  Z-score: $(fmt(single_z_inf, digits=2))")
        println(io, "Susceptible - Std: $(fmt(single_std_sus))  Z-score: $(fmt(single_z_sus, digits=2))")
        println(io, "Expected infectious (simple estimate): $(fmt(single_expected_infectious_simple))")
        println(io, "Expected infectious (age-adjusted):    $(fmt(single_exp_inf_total))")
        println(io, "Observed infectious:                   $single_infectious_cg")

        println(io, "\n=== Expected vs Observed Infections at Concert ===")
        println(io, "Expected infections: $(fmt(single_exp_concert_inf))")
        println(io, "Observed infections: $single_infected_at_concert")
        println(io, "Std:                 $(fmt(single_std_concert_inf))")
        println(io, "Z-score:             $(fmt(single_z_concert, digits=2))")


    # -------------------------------------------------------------------------
    # BATCH
    # -------------------------------------------------------------------------
    elseif run_mode == :batch

        println(io, "=== Simulation Metrics (n=$n_simulations, concert day $concert_date) ===")
        dist_row("Total infected in population", total_infected_v, io)
        dist_row("Attack rate (%)", attack_rate_v, io)
        dist_row("R0", r0_v, io)
        dist_row("Infectious in population on concert day", infectious_population_v, io)
        dist_row("Infectious concert-goers on concert day", infectious_concertgoers_v, io)
        dist_row("Expected infectious concert-goers (simple)", expected_infectious_simple_v, io)
        dist_row("Infected at concert", infected_at_concert_v, io)

        println(io, "\n=== Before Concert ===")
        dist_row("Susceptible at concert", susceptible_before_v, io)
        dist_row("Exposed before concert day", exposed_before_v, io)
        dist_row("Exposed same day before concert", same_day_other_v, io)
        dist_row("Infectious", infectious_before_v, io)
        dist_row("Recovered/immune", recovered_before_v, io)
        dist_row("Dead", dead_before_v, io)

        println(io, "\n=== After Concert ===")
        dist_row("Infection rate among susceptible (%)", infection_rate_v, io)

        println(io, "\n=== Expected vs Observed by Age Group ===")
        println(io, rpad("Age group", 10), " | ",
                rpad("Pop inf%", 14), " | ",
                rpad("Pop sus%", 14), " | ",
                rpad("Exp inf", 14), " | ",
                rpad("Obs inf", 14), " | ",
                rpad("Exp sus", 14), " | ",
                "Obs sus")
        println(io, "-"^105)

        total_exp_inf_v = zeros(n_simulations)
        total_obs_inf_v = zeros(n_simulations)
        total_exp_sus_v = zeros(n_simulations)
        total_obs_sus_v = zeros(n_simulations)

        for age in age_order
            for j in 1:n_simulations
                total_exp_inf_v[j] += exp_inf_by_age[age][j]
                total_obs_inf_v[j] += obs_inf_by_age[age][j]
                total_exp_sus_v[j] += exp_sus_by_age[age][j]
                total_obs_sus_v[j] += obs_sus_by_age[age][j]
            end
            println(io, rpad(age, 10), " | ",
                    rpad("$(fmt(mean(pop_inf_rate_by_age[age])))±$(fmt(std(pop_inf_rate_by_age[age])))", 14), " | ",
                    rpad("$(fmt(mean(pop_sus_rate_by_age[age])))±$(fmt(std(pop_sus_rate_by_age[age])))", 14), " | ",
                    rpad("$(fmt(mean(exp_inf_by_age[age])))±$(fmt(std(exp_inf_by_age[age])))", 14), " | ",
                    rpad("$(fmt(mean(obs_inf_by_age[age])))±$(fmt(std(obs_inf_by_age[age])))", 14), " | ",
                    rpad("$(fmt(mean(exp_sus_by_age[age])))±$(fmt(std(exp_sus_by_age[age])))", 14), " | ",
                    "$(fmt(mean(obs_sus_by_age[age])))±$(fmt(std(obs_sus_by_age[age])))")
        end
        println(io, "-"^105)

        tei_mean = mean(total_exp_inf_v); tei_std = std(total_exp_inf_v)
        toi_mean = mean(total_obs_inf_v); toi_std = std(total_obs_inf_v)
        tes_mean = mean(total_exp_sus_v); tes_std = std(total_exp_sus_v)
        tos_mean = mean(total_obs_sus_v); tos_std = std(total_obs_sus_v)
        z_inf = (toi_mean - tei_mean) / toi_std
        z_sus = (tos_mean - tes_mean) / tos_std

        println(io, rpad("Total", 10), " | ",
                rpad("", 14), " | ", rpad("", 14), " | ",
                rpad("$(fmt(tei_mean))±$(fmt(tei_std))", 14), " | ",
                rpad("$(fmt(toi_mean))±$(fmt(toi_std))", 14), " | ",
                rpad("$(fmt(tes_mean))±$(fmt(tes_std))", 14), " | ",
                "$(fmt(tos_mean))±$(fmt(tos_std))")
        println(io, "\nInfectious  - Z-score: $(fmt(z_inf, digits=2))")
        println(io, "Susceptible - Z-score: $(fmt(z_sus, digits=2))")
        println(io, "Expected infectious (simple estimate): $(fmt(mean(expected_infectious_simple_v))) ± $(fmt(std(expected_infectious_simple_v)))")
        println(io, "Expected infectious (age-adjusted):    $(fmt(tei_mean)) ± $(fmt(tei_std))")
        println(io, "Observed infectious:                   $(fmt(toi_mean)) ± $(fmt(toi_std))")

        println(io, "\n=== Expected vs Observed Infections at Concert ===")
        println(io, "Expected infections: $(fmt(mean(expected_concert_infections_v))) ± $(fmt(std(expected_concert_infections_v)))")
        println(io, "Observed infections: $(fmt(mean(observed_concert_infections_v))) ± $(fmt(std(observed_concert_infections_v)))")
        z_concert = (mean(observed_concert_infections_v) - mean(expected_concert_infections_v)) / std(observed_concert_infections_v)
        println(io, "Z-score:             $(fmt(z_concert, digits=2))")


    # -------------------------------------------------------------------------
    # BATCH OF BATCHES
    # -------------------------------------------------------------------------
    elseif run_mode == :batch_of_batches

        println(io, "=== Infections at Concert — Distribution by Day ===")
        println(io, rpad("Day", 5), " | ",
                rpad("Mean", 8), " | ", rpad("Std", 8), " | ", rpad("CV%", 8), " | ",
                rpad("Min", 6), " | ", rpad("P25", 6), " | ", rpad("Median", 8), " | ",
                rpad("P75", 6), " | ", rpad("P90", 6), " | ", rpad("P95", 6), " | ", "Max")
        println(io, "-"^95)
        for day in concert_days_range
            s = summary_by_day[day]
            println(io, rpad(day, 5), " | ",
                    rpad(fmt(s.mean), 8), " | ", rpad(fmt(s.std), 8), " | ", rpad(fmt(s.cv), 8), " | ",
                    rpad(fmt(s.min), 6), " | ", rpad(fmt(s.p25), 6), " | ", rpad(fmt(s.median), 8), " | ",
                    rpad(fmt(s.p75), 6), " | ", rpad(fmt(s.p90), 6), " | ", rpad(fmt(s.p95), 6), " | ",
                    fmt(s.max))
        end

        println(io, "\n=== Concert Population Metrics by Day (mean ± std across $n_simulations runs) ===")
        println(io, rpad("Day", 5), " | ",
                rpad("Inf at concert", 16), " | ",
                rpad("Susceptible CG", 16), " | ",
                rpad("Infectious CG", 16), " | ",
                "Infectious pop")
        println(io, "-"^75)
        for day in concert_days_range
            m = concert_metrics_by_day[day]
            println(io, rpad(day, 5), " | ",
                    rpad("$(fmt(m.infected_at_concert_mean))±$(fmt(m.infected_at_concert_std))", 16), " | ",
                    rpad("$(fmt(m.susceptible_cg_mean))±$(fmt(m.susceptible_cg_std))", 16), " | ",
                    rpad("$(fmt(m.infectious_cg_mean))±$(fmt(m.infectious_cg_std))", 16), " | ",
                    "$(fmt(m.infectious_pop_mean))±$(fmt(m.infectious_pop_std))")
        end

    end

end  # close file

println("Metrics saved to Concert_Project_copy/Results/concert_analysis_summary.txt")




## =============================================================================
## === PLOTS ===================================================================
## =============================================================================

# -------------------------------------------------------------------------
# SINGLE: gemsplot + setting plot (single run, no ribbon)
# -------------------------------------------------------------------------
if run_mode == :single

    gp = gemsplot(single_rd)
    png(gp, "Concert_Project_copy/Plots/S5_epidemic_curves_day$(concert_date).png")

    tick_cases_concert  = single_rd.data["dataframes"]["tick_cases_per_setting"]
    tick_cases_filtered = Vector{DataFrameRow}()
    for row in eachrow(tick_cases_concert)
        row.setting_type in ['h', 'c', 'o', 'g', 'm'] && push!(tick_cases_filtered, row)
    end
    single_rd.data["dataframes"]["tick_cases_per_setting"] = DataFrame(tick_cases_filtered)
    gp1 = gemsplot(single_rd, type = :TickCasesBySetting)
    png(gp1, "Concert_Project_copy/Plots/S5_setting_infections_day$(concert_date).png")


# -------------------------------------------------------------------------
# BATCH: ribbon epidemic curves, setting infections, boxplot
# -------------------------------------------------------------------------
elseif run_mode == :batch

    day = concert_date

    p1 = plot(title = "Cases per Day", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    shaded_series!(p1,
        [per_day_tick_general[day]["exposed"],
         per_day_tick_general[day]["infectious"],
         per_day_tick_general[day]["recovered"],
         per_day_tick_general[day]["dead"]],
        [:blue, :orange, :green, :black],
        ["Exposed", "Became Infectious", "Recovered", "Died"]
    )

    p2 = plot(title = "Cumulative Cases", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    shaded_series!(p2,
        [per_day_tick_general[day]["cumulative_infections"],
         per_day_tick_general[day]["cumulative_recoveries"],
         per_day_tick_general[day]["cumulative_deaths"]],
        [:blue, :orange, :black],
        ["Infections", "Recoveries", "Deaths"]
    )

    gp_gen = plot(p1, p2, layout = (2, 1), size = (700, 800), titlefontsize = 10, dpi = 300)
    png(gp_gen, "Concert_Project_copy/Plots/S6_epidemic_curves_day$(concert_date).png")

    gp_set = plot(title = "Infections per Day by Setting", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    for setting in setting_list
        if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
            avg, lo, hi = ribbon_data(per_day_tick_settings[day][setting])
            plot!(gp_set, 1:length(avg), avg,
                ribbon = (avg .- lo, hi .- avg), fillalpha = 0.3,
                label = setting_labels[setting], color = setting_colors[setting], linewidth = 2)
        end
    end
    png(gp_set, "Concert_Project_copy/Plots/S6_setting_infections_day$(concert_date).png")

    gp_box = boxplot(["Infected at concert"], [infected_at_concert_v],
        title = "Distribution of Infections at Concert",
        ylabel = "Number of Infections", legend = false,
        dpi = 300, color = :blue, fillalpha = 0.5)
    png(gp_box, "Concert_Project_copy/Plots/S6_infections_at_concert_boxplot_day$(concert_date).png")


# -------------------------------------------------------------------------
# BATCH OF BATCHES: 4 global plots + on-demand single-day function
# -------------------------------------------------------------------------
elseif run_mode == :batch_of_batches

    days_vec      = collect(concert_days_range)
    n_days        = length(days_vec)
    grad          = cgrad([:blue, :red], n_days)
    day_color_map = Dict(day => grad[i] for (i, day) in enumerate(days_vec))

    # --- Boxplot, Violin, Mean by day ---
    data = [infected_distributions[day] for day in days_vec]

    gp_box = boxplot(
        repeat(days_vec, inner = n_simulations), vcat(data...),
        title = "Distribution of Infections at Concert by Day",
        xlabel = "Concert Day", ylabel = "Infections at Concert",
        legend = false, dpi = 300, color = :blue, fillalpha = 0.5, linewidth = 1)
    png(gp_box, "Concert_Project_copy/Plots/BOB_infections_at_concert_boxplot.png")

    gp_vio = violin(
        repeat(days_vec, inner = n_simulations), vcat(data...),
        title = "Distribution of Infections at Concert by Day",
        xlabel = "Concert Day", ylabel = "Infections at Concert",
        legend = false, dpi = 300, color = :blue, fillalpha = 0.5, linewidth = 1)
    png(gp_vio, "Concert_Project_copy/Plots/BOB_infections_at_concert_violin.png")

    gp_mean = plot(days_vec,
        [summary_by_day[day].mean for day in days_vec],
        ribbon    = [summary_by_day[day].std for day in days_vec],
        fillalpha = 0.3,
        title = "Mean Infections at Concert by Day",
        xlabel = "Concert Day", ylabel = "Mean Infections at Concert",
        label = "Mean ± Std", color = :blue, linewidth = 2, dpi = 300)
    png(gp_mean, "Concert_Project_copy/Plots/BOB_infections_at_concert_mean_by_day.png")

    # --- Plot A: Epidemic curves — one line per concert day ---
    pA_exp = plot(title = "Exposed per Day by Concert Day",    xlabel = "Day", ylabel = "Individuals", dpi = 300)
    pA_inf = plot(title = "Infectious per Day by Concert Day", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    pA_rec = plot(title = "Recovered per Day by Concert Day",  xlabel = "Day", ylabel = "Individuals", dpi = 300)
    pA_ded = plot(title = "Dead per Day by Concert Day",       xlabel = "Day", ylabel = "Individuals", dpi = 300)

    for day in concert_days_range
        c = day_color_map[day]
        for (p_ax, key) in [(pA_exp, "exposed"), (pA_inf, "infectious"), (pA_rec, "recovered"), (pA_ded, "dead")]
            avg, lo, hi = ribbon_data(per_day_tick_general[day][key])
            plot!(p_ax, 1:length(avg), avg,
                ribbon = (avg .- lo, hi .- avg), fillalpha = 0.15,
                label = "Day $day", color = c, linewidth = 1.5)
        end
    end
    gpA = plot(pA_exp, pA_inf, pA_rec, pA_ded,
        layout = (2, 2), size = (1200, 800), titlefontsize = 10)
    png(gpA, "Concert_Project_copy/Plots/BOB_epidemic_curves_by_concert_day.png")

    # --- Plot B: Grand average epidemic curves + cumulative cases ---
    pB1 = plot(title = "Cases per Day — Grand Average", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    for (key, color, label) in [
            ("exposed",    :blue,   "Exposed"),
            ("infectious", :orange, "Became Infectious"),
            ("recovered",  :green,  "Recovered"),
            ("dead",       :black,  "Died")]
        avg, lo, hi = grand_average_ribbon(key)
        plot!(pB1, 1:length(avg), avg,
            ribbon = (avg .- lo, hi .- avg), fillalpha = 0.2,
            label = label, color = color, linewidth = 2)
    end

    pB2 = plot(title = "Cumulative Cases — Grand Average", xlabel = "Day", ylabel = "Individuals", dpi = 300)
    for (key, color, label) in [
            ("cumulative_infections", :blue,   "Infections"),
            ("cumulative_recoveries", :orange, "Recoveries"),
            ("cumulative_deaths",     :black,  "Deaths")]
        avg, lo, hi = grand_average_ribbon(key)
        plot!(pB2, 1:length(avg), avg,
            ribbon = (avg .- lo, hi .- avg), fillalpha = 0.2,
            label = label, color = color, linewidth = 2)
    end

    gpB = plot(pB1, pB2, layout = (2, 1), size = (700, 800), titlefontsize = 10, dpi = 300)
    png(gpB, "Concert_Project_copy/Plots/BOB_epidemic_curves_grand_average.png")

    # --- Plot C: Setting infections — one line per concert day ---
    setting_plots_C = Dict(s => plot(
        title   = "$(setting_labels[s]) — by Concert Day",
        xlabel  = "Day", ylabel = "Individuals",
        dpi     = 300, legend = :topright
    ) for s in setting_list)

    for day in concert_days_range
        c = day_color_map[day]
        for setting in setting_list
            if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
                avg, lo, hi = ribbon_data(per_day_tick_settings[day][setting])
                plot!(setting_plots_C[setting], 1:length(avg), avg,
                    ribbon = (avg .- lo, hi .- avg), fillalpha = 0.15,
                    label = "Day $day", color = c, linewidth = 1.5)
            end
        end
    end
    gpC = plot([setting_plots_C[s] for s in setting_list]...,
        layout = (3, 2), size = (1200, 1000), titlefontsize = 9)
    png(gpC, "Concert_Project_copy/Plots/BOB_setting_infections_by_concert_day.png")

    # --- Plot D: Setting infections — grand average ---
    pD = plot(title = "Infections per Day by Setting — Grand Average",
              xlabel = "Day", ylabel = "Individuals", dpi = 300)
    for setting in setting_list
        avg, lo, hi = grand_average_ribbon_setting(setting)
        isempty(avg) && continue
        plot!(pD, 1:length(avg), avg,
            ribbon = (avg .- lo, hi .- avg), fillalpha = 0.3,
            label = setting_labels[setting], color = setting_colors[setting], linewidth = 2)
    end
    png(pD, "Concert_Project_copy/Plots/BOB_setting_infections_grand_average.png")

    # --- On-demand single-day plots ---
    # Call plot_day(25) after running this file to get epidemic + setting plots for any day.
    function plot_day(day::Int)
        if !haskey(per_day_tick_general, day)
            println("No data for day $day. Available: $(collect(concert_days_range))")
            return
        end
        pE = plot(title = "Cases per Day — Concert Day $day", xlabel = "Day", ylabel = "Individuals", dpi = 300)
        shaded_series!(pE,
            [per_day_tick_general[day]["exposed"],
             per_day_tick_general[day]["infectious"],
             per_day_tick_general[day]["recovered"],
             per_day_tick_general[day]["dead"]],
            [:blue, :orange, :green, :black],
            ["Exposed", "Became Infectious", "Recovered", "Died"])
        png(pE, "Concert_Project_copy/Plots/BOB_epidemic_curves_day$(day).png")

        pF = plot(title = "Infections per Day by Setting — Concert Day $day",
                  xlabel = "Day", ylabel = "Individuals", dpi = 300)
        for setting in setting_list
            if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
                avg, lo, hi = ribbon_data(per_day_tick_settings[day][setting])
                plot!(pF, 1:length(avg), avg,
                    ribbon = (avg .- lo, hi .- avg), fillalpha = 0.3,
                    label = setting_labels[setting], color = setting_colors[setting], linewidth = 2)
            end
        end
        png(pF, "Concert_Project_copy/Plots/BOB_setting_infections_day$(day).png")
        println("Saved: BOB_epidemic_curves_day$(day).png  |  BOB_setting_infections_day$(day).png")
    end

    # plot_day(25)   # uncomment or call interactively

end

println("\nAnalysis complete.")