using StatsPlots

day_str = actual_event_size == 0 ? "No_Concert" :
          length(concert_days_range) == 1 ?
          "day$(first(concert_days_range))" :
          "day$(first(concert_days_range))_$(step(concert_days_range))_$(last(concert_days_range))"

filename = "concert_analysis_$(day_str)_x$(n_simulations).txt"




setting_colors = Dict('h' => :orange, 'c' => :red, 'o' => :purple, 'g' => :blue, 'm' => :brown)
const setting_labels = Dict('h' => "Household", 'c' => "SchoolClass", 'o' => "Office", 'g' => "GlobalSetting", 'm' => "Municipality")
const setting_list = ['h', 'c', 'o', 'g', 'm']

function fmt(x; digits=2)
    round(x, digits=digits)
end


function summary_stats(v)
    (
        mean=mean(v),
        std=length(v) > 1 ? std(v) : 0.00,
        min=minimum(v),
        p25=quantile(v, 0.25),
        median=median(v),
        p75=quantile(v, 0.75),
        max=maximum(v)
    )
end

function print_table_header(io)
    println(io, rpad("Metric", 16), " | ",
        rpad("Mean", 9), " | ", rpad("Std", 9), " | ",
        rpad("Min", 9), " | ", rpad("P25", 9), " | ",
        rpad("Median", 9), " | ", rpad("P75", 9), " | ", "Max")
    println(io, "-"^95)
end

function print_metric_row(io, label, m)
    println(io, rpad(label, 16), " | ",
        rpad(fmt(m.mean), 9), " | ", rpad(fmt(m.std), 9), " | ",
        rpad(fmt(m.min), 9), " | ", rpad(fmt(m.p25), 9), " | ",
        rpad(fmt(m.median), 9), " | ", rpad(fmt(m.p75), 9), " | ",
        fmt(m.max))
end


function ribbon_data(series_list)
    mat = hcat(series_list...)
    avg = mean(mat, dims=2)[:]
    lo = minimum(mat, dims=2)[:]
    hi = maximum(mat, dims=2)[:]
    return avg, lo, hi
end


function shaded_series!(p, series_list, colors, labels)
    for (series, color, label) in zip(series_list, colors, labels)
        mat = hcat(series...)
        avg = mean(mat, dims=2)[:]
        lo = minimum(mat, dims=2)[:]
        hi = maximum(mat, dims=2)[:]
        plot!(p, 1:length(avg), avg,
            ribbon=(avg .- lo, hi .- avg),
            fillalpha=0.2,
            label=label,
            color=color,
            linewidth=2
        )
    end
end


## === GLOBAL + PER-DAY METRICS ===
open("Concert_Project/Results/$(filename)", "w") do io

    println(io, "=== Concert Analysis ===")

    for day in concert_days_range
        title_str = actual_event_size == 0 ? "No Concert" : "Day $day"

        println(io, "\n\n##############################")
        println(io, "### Concert $title_str")
        println(io, "##############################")


        ## --- Global epidemic metrics (this day's runs) ---
        println(io, "\n--- Global Epidemic Metrics ---")
        print_table_header(io)
        print_metric_row(io, "Total infected", summary_stats(results_by_day[day].sim_metrics.total_infected))
        print_metric_row(io, "Attack rate", summary_stats(results_by_day[day].sim_metrics.attack_rate))
        print_metric_row(io, "R0", summary_stats(results_by_day[day].sim_metrics.r0))

        infectious_pop_v = [run[day] for run in results_by_day[day].cl_timeseries["total_infectious"]]
        print_metric_row(io, "Infectious pop", summary_stats(infectious_pop_v))


        ## --- Sitting group ---
        println(io, "\n--- Sitting (occupation 1) ---")
        print_table_header(io)
        print_metric_row(io, "Susceptible", results_by_day[day].concert[:susceptible_sitting])
        print_metric_row(io, "Infectious", results_by_day[day].concert[:infectious_sitting])
        print_metric_row(io, "Exposed", results_by_day[day].concert[:exposed_sitting])
        print_metric_row(io, "Recovered", results_by_day[day].concert[:recovered_sitting])
        print_metric_row(io, "Dead", results_by_day[day].concert[:dead_sitting])
        print_metric_row(io, "Same day other", results_by_day[day].concert[:same_day_other_sitting])
        print_metric_row(io, "Infected", results_by_day[day].concert[:infected_sitting])

        m_inf = results_by_day[day].concert[:infected_sitting]
        m_sus = results_by_day[day].concert[:susceptible_sitting]
        infection_rate_sitting = m_inf.mean / m_sus.mean * 100
        println(io, "\nInfection rate (sitting): $(fmt(infection_rate_sitting))%")

        println(io, "\nExpected vs Observed (sitting):")
        print_table_header(io)
        print_metric_row(io, "Expected", results_by_day[day].concert[:expected_sitting])
        print_metric_row(io, "Std", results_by_day[day].concert[:std_sitting])
        print_metric_row(io, "Z-score", results_by_day[day].concert[:z_sitting])


        ## --- Standing group ---
        println(io, "\n--- Standing (occupation 2) ---")
        print_table_header(io)
        print_metric_row(io, "Susceptible", results_by_day[day].concert[:susceptible_standing])
        print_metric_row(io, "Infectious", results_by_day[day].concert[:infectious_standing])
        print_metric_row(io, "Exposed", results_by_day[day].concert[:exposed_standing])
        print_metric_row(io, "Recovered", results_by_day[day].concert[:recovered_standing])
        print_metric_row(io, "Dead", results_by_day[day].concert[:dead_standing])
        print_metric_row(io, "Same day other", results_by_day[day].concert[:same_day_other_standing])
        print_metric_row(io, "Infected", results_by_day[day].concert[:infected_standing])

        m_inf = results_by_day[day].concert[:infected_standing]
        m_sus = results_by_day[day].concert[:susceptible_standing]
        infection_rate_standing = m_inf.mean / m_sus.mean * 100
        println(io, "\nInfection rate (standing): $(fmt(infection_rate_standing))%")

        println(io, "\nExpected vs Observed (standing):")
        print_table_header(io)
        print_metric_row(io, "Expected", results_by_day[day].concert[:expected_standing])
        print_metric_row(io, "Std", results_by_day[day].concert[:std_standing])
        print_metric_row(io, "Z-score", results_by_day[day].concert[:z_standing])

        println(io, "\nPer-generation breakdown (sitting):")
        gen_sit = results_by_day[day].chain.gen_sitting
        for gen in 1:size(gen_sit, 1)
            row_vals = Float64.(gen_sit[gen, :])
            s = summary_stats(row_vals)
            print_metric_row(io, "Generation $gen", s)
        end

        println(io, "\nPer-generation breakdown (standing):")
        gen_sta = results_by_day[day].chain.gen_standing
        for gen in 1:size(gen_sta, 1)
            row_vals = Float64.(gen_sta[gen, :])
            s = summary_stats(row_vals)
            print_metric_row(io, "Generation $gen", s)
        end
    end
end

println("Metrics saved to Concert_Project/Results/$(filename)")

println("\n=== Expected Infections per 100 Susceptible ===")
for day in concert_days_range
    expected_per100_sitting = results_by_day[day].concert[:expected_sitting].mean / results_by_day[day].concert[:susceptible_sitting].mean * 100
    expected_per100_standing = results_by_day[day].concert[:expected_standing].mean / results_by_day[day].concert[:susceptible_standing].mean * 100

    println("Day $day | Sitting: $(fmt(expected_per100_sitting)) | Standing: $(fmt(expected_per100_standing))")
end

## === Plots ===
function plot_day(day)
    ts = results_by_day[day].timeseries
    title_str = actual_event_size == 0 ? "No Concert" : "Day $day"

    avg_exposed = mean(hcat(ts["exposed"]...), dims=2)[:]
    avg_infectious = mean(hcat(ts["infectious"]...), dims=2)[:]
    avg_recovered = mean(hcat(ts["recovered"]...), dims=2)[:]

    println("Peak exposed:    $(maximum(avg_exposed)) at tick $(argmax(avg_exposed))")
    println("Peak infectious: $(maximum(avg_infectious)) at tick $(argmax(avg_infectious))")
    println("Peak recovered:  $(maximum(avg_recovered)) at tick $(argmax(avg_recovered))")


    p1 = plot(title="Epidemic Curves — $title_str", xlabel="Tick", ylabel="Count")
    shaded_series!(p1,
        [ts["exposed"], ts["infectious"], ts["recovered"], ts["dead"]],
        [:blue, :red, :green, :black],
        ["Exposed", "Infectious", "Recovered", "Dead"]
    )



    p2 = plot(title="Cumulative Cases — $title_str", xlabel="Tick", ylabel="Count")
    shaded_series!(p2,
        [ts["cumulative_infections"], ts["cumulative_recoveries"], ts["cumulative_deaths"]],
        [:blue, :green, :black],
        ["Infections", "Recoveries", "Deaths"]
    )

    p3 = plot(title="Effective R — $title_str", xlabel="Tick", ylabel="R")
    shaded_series!(p3,
        [ts["effectiveR_rolling"], ts["effectiveR_inhh"], ts["effectiveR_outhh"]],
        [:blue, :green, :black],
        ["Overall", "In Household", "Out Household"]
    )

    p_overview = plot(p1, p2, p3, layout=(3, 1), size=(800, 900), dpi=300)
    savefig(p_overview, "Concert_Project/Plots/epidemic_overview_$(day_str).png")


    p4 = plot(title="Cases by Setting — $title_str", xlabel="Tick", ylabel="Count", dpi=300)
    settings = results_by_day[day].settings
    for s in setting_list
        shaded_series!(p4, [settings[s]], [setting_colors[s]], [setting_labels[s]])
    end
    savefig(p4, "Concert_Project/Plots/cases_by_setting_$(day_str).png")


    gen_sit = results_by_day[day].chain.gen_sitting
    gen_sta = results_by_day[day].chain.gen_standing

    avg_sit = mean(gen_sit, dims=2)[:]
    lo_sit = minimum(gen_sit, dims=2)[:]
    hi_sit = maximum(gen_sit, dims=2)[:]

    avg_sta = mean(gen_sta, dims=2)[:]
    lo_sta = minimum(gen_sta, dims=2)[:]
    hi_sta = maximum(gen_sta, dims=2)[:]

    p5 = plot(title="Downstream Infections by Generation — $title_str",
        xlabel="Generation", ylabel="Infections", dpi=300)

    lo_sit = minimum(gen_sit, dims=2)[:]
    hi_sit = maximum(gen_sit, dims=2)[:]
    plot!(p5, 1:length(avg_sit), avg_sit,
        ribbon=(avg_sit .- lo_sit, hi_sit .- avg_sit),
        fillalpha=0.2, label="Sitting", color=:blue, linewidth=2)

    lo_sta = minimum(gen_sta, dims=2)[:]
    hi_sta = maximum(gen_sta, dims=2)[:]
    plot!(p5, 1:length(avg_sta), avg_sta,
        ribbon=(avg_sta .- lo_sta, hi_sta .- avg_sta),
        fillalpha=0.2, label="Standing", color=:red, linewidth=2)

    savefig(p5, "Concert_Project/Plots/downstream_by_generation_$(day_str).png")

end



function plot_infected_boxplot()
    groups = Int[]
    sit_values = Float64[]
    sta_values = Float64[]
    for day in concert_days_range
        raw = results_by_day[day].concert_raw
        append!(sit_values, [r.infected_sitting for r in raw])
        append!(sta_values, [r.infected_standing for r in raw])
        append!(groups, fill(day, length(raw)))
    end

    p6 = boxplot(groups, sit_values,
        title="Infected at Concert (Sitting)", xlabel="Concert Day", ylabel="Infected",
        legend=false, dpi=300, color=:blue)

    p7 = boxplot(groups, sta_values,
        title="Infected at Concert (Standing)", xlabel="Concert Day", ylabel="Infected",
        legend=false, dpi=300, color=:red)

    p8 = plot(p6, p7, layout=(2, 1), size=(800, 800), dpi=300)
    savefig(p8, "Concert_Project/Plots/infected_at_concert_boxplot_$(day_str).png")



end

## === BOB Plots ===

function plot_concert_impact_by_day()
    days_vec = collect(concert_days_range)

    sit_gen1 = Float64[];
    sit_gen1_lo = Float64[];
    sit_gen1_hi = Float64[]
    sit_total = Float64[];
    sit_total_lo = Float64[];
    sit_total_hi = Float64[]
    sta_gen1 = Float64[];
    sta_gen1_lo = Float64[];
    sta_gen1_hi = Float64[]
    sta_total = Float64[];
    sta_total_lo = Float64[];
    sta_total_hi = Float64[]

    for day in days_vec
        gen_sit = results_by_day[day].chain.gen_sitting
        gen_sta = results_by_day[day].chain.gen_standing

        push!(sit_gen1, size(gen_sit, 1) >= 1 ? mean(gen_sit[1, :]) : 0.0)
        push!(sit_gen1_lo, size(gen_sit, 1) >= 1 ? minimum(gen_sit[1, :]) : 0.0)
        push!(sit_gen1_hi, size(gen_sit, 1) >= 1 ? maximum(gen_sit[1, :]) : 0.0)

        push!(sta_gen1, size(gen_sta, 1) >= 1 ? mean(gen_sta[1, :]) : 0.0)
        push!(sta_gen1_lo, size(gen_sta, 1) >= 1 ? minimum(gen_sta[1, :]) : 0.0)
        push!(sta_gen1_hi, size(gen_sta, 1) >= 1 ? maximum(gen_sta[1, :]) : 0.0)

        push!(sit_total, results_by_day[day].chain.aggregated[:total_downstream_sitting].mean)
        push!(sit_total_lo, results_by_day[day].chain.aggregated[:total_downstream_sitting].min)
        push!(sit_total_hi, results_by_day[day].chain.aggregated[:total_downstream_sitting].max)

        push!(sta_total, results_by_day[day].chain.aggregated[:total_downstream_standing].mean)
        push!(sta_total_lo, results_by_day[day].chain.aggregated[:total_downstream_standing].min)
        push!(sta_total_hi, results_by_day[day].chain.aggregated[:total_downstream_standing].max)
    end

    p9 = plot(title="Downstream Infections — Sitting", xlabel="Concert Day", ylabel="Infections")
    plot!(p9, days_vec, sit_gen1,
        ribbon=(sit_gen1 .- sit_gen1_lo, sit_gen1_hi .- sit_gen1),
        label="Gen 1", color=:blue, linewidth=2, fillalpha=0.2)
    plot!(p9, days_vec, sit_total,
        ribbon=(sit_total .- sit_total_lo, sit_total_hi .- sit_total),
        label="Total", color=:blue, linewidth=2, linestyle=:dash, fillalpha=0.2)

    p10 = plot(title="Downstream Infections — Standing", xlabel="Concert Day", ylabel="Infections")
    plot!(p10, days_vec, sta_gen1,
        ribbon=(sta_gen1 .- sta_gen1_lo, sta_gen1_hi .- sta_gen1),
        label="Gen 1", color=:red, linewidth=2, fillalpha=0.2)
    plot!(p10, days_vec, sta_total,
        ribbon=(sta_total .- sta_total_lo, sta_total_hi .- sta_total),
        label="Total", color=:red, linewidth=2, linestyle=:dash, fillalpha=0.2)

    p_overview = plot(p9, p10, layout=(2, 1), size=(800, 800), dpi=300)
    savefig(p_overview, "Concert_Project/Plots/downstream_infections_by_day.png")
end

function plot_heatmaps()
    days_vec = collect(concert_days_range)
    step_size = max(1, length(days_vec) ÷ 10)
    tick_positions = days_vec[1:step_size:end]

    # --- Cumulative infections ---
    heatmap_matrix_cum = nothing
    for day in concert_days_range
        avg, _, _ = ribbon_data(results_by_day[day].timeseries["cumulative_infections"])
        if heatmap_matrix_cum === nothing
            heatmap_matrix_cum = avg'
        else
            heatmap_matrix_cum = vcat(heatmap_matrix_cum, avg')
        end
    end
    n_ticks = size(heatmap_matrix_cum, 2)

    p1 = heatmap(1:n_ticks, days_vec, heatmap_matrix_cum ./ 1000,
        title="Mean Cumulative Infections by Concert Day",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="Infections (thousands)",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p1, "Concert_Project/Plots/heatmap_cumulative_infections_$(day_str).png")

    # --- Mean exposed ---
    heatmap_matrix_exp = nothing
    for day in concert_days_range
        avg, _, _ = ribbon_data(results_by_day[day].timeseries["exposed"])
        if heatmap_matrix_exp === nothing
            heatmap_matrix_exp = avg'
        else
            heatmap_matrix_exp = vcat(heatmap_matrix_exp, avg')
        end
    end

    p2 = heatmap(1:n_ticks, days_vec, heatmap_matrix_exp,
        title="Mean Exposed by Concert Day",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="Exposed",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p2, "Concert_Project/Plots/heatmap_exposed_$(day_str).png")

    # --- Peak exposed distribution ---
    peak_matrix = zeros(Float64, length(days_vec), n_ticks)
    for (i, day) in enumerate(days_vec)
        for run in results_by_day[day].timeseries["exposed"]
            peak_tick = argmax(run)
            peak_matrix[i, peak_tick] += 1
        end
    end

    p3 = heatmap(1:n_ticks, days_vec, peak_matrix,
        title="Distribution of Peak Exposed Tick by Concert Day",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="N runs",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p3, "Concert_Project/Plots/heatmap_peak_exposed_distribution_$(day_str).png")
end


function plot_heatmaps_subset(; tick_range, concert_range)
    days_vec = collect(concert_range)
    tick_vec = collect(tick_range)
    step_size = max(1, length(days_vec) ÷ 10)
    tick_positions = days_vec[1:step_size:end]

    # --- Cumulative infections ---
    heatmap_matrix_cum = nothing
    for day in days_vec
        avg, _, _ = ribbon_data(results_by_day[day].timeseries["cumulative_infections"])
        avg_subset = avg[tick_vec]
        if heatmap_matrix_cum === nothing
            heatmap_matrix_cum = avg_subset'
        else
            heatmap_matrix_cum = vcat(heatmap_matrix_cum, avg_subset')
        end
    end

    p1 = heatmap(tick_vec, days_vec, heatmap_matrix_cum ./ 1000,
        title="Mean Cumulative Infections by Concert Day (subset)",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="Infections (thousands)",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p1, "Concert_Project/Plots/heatmap_cumulative_infections_subset.png")

    # --- Mean exposed ---
    heatmap_matrix_exp = nothing
    for day in days_vec
        avg, _, _ = ribbon_data(results_by_day[day].timeseries["exposed"])
        avg_subset = avg[tick_vec]
        if heatmap_matrix_exp === nothing
            heatmap_matrix_exp = avg_subset'
        else
            heatmap_matrix_exp = vcat(heatmap_matrix_exp, avg_subset')
        end
    end

    p2 = heatmap(tick_vec, days_vec, heatmap_matrix_exp,
        title="Mean Exposed by Concert Day (subset)",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="Exposed",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p2, "Concert_Project/Plots/heatmap_exposed_subset.png")

    # --- Peak exposed distribution ---
    peak_matrix = zeros(Float64, length(days_vec), length(tick_vec))
    for (i, day) in enumerate(days_vec)
        for run in results_by_day[day].timeseries["exposed"]
            peak_tick = argmax(run)
            if peak_tick in tick_range
                peak_matrix[i, findfirst(==(peak_tick), tick_vec)] += 1
            end
        end
    end

    p3 = heatmap(tick_vec, days_vec, peak_matrix,
        title="Peak Exposed Tick Distribution (subset)",
        xlabel="Tick", ylabel="Concert Day",
        colorbar_title="N runs",
        color=:viridis, dpi=300,
        yticks=(tick_positions, string.(tick_positions)))
    savefig(p3, "Concert_Project/Plots/heatmap_peak_exposed_distribution_subset.png")
end

## === Generate plots automatically ===
plot_infected_boxplot()

if length(concert_days_range) > 1
    plot_concert_impact_by_day()
    plot_heatmaps()
end

if length(concert_days_range) == 1
    plot_day(first(concert_days_range))
end

sorted = sort(collect(concert_days_range),
    by=day -> mean(results_by_day[day].sim_metrics.total_infected),
    rev=true)

for day in sorted[1:min(5, length(sorted))]
    println("Day $day: $(fmt(mean(results_by_day[day].sim_metrics.total_infected))) infected")
end

println("\nPlots saved to Concert_Project/Plots/")
if length(concert_days_range) > 1
    println("Call plot_day(day) for detailed per-day plots, e.g. plot_day($(first(concert_days_range)))")
    println("Call plot_heatmaps_subset(tick_range= , concert_range= )")
end