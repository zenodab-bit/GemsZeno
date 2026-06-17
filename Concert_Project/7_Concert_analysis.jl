using StatsPlots

day_str = length(concert_days_range) == 1 ?
          "day$(first(concert_days_range))" :
          "day$(first(concert_days_range))_$(step(concert_days_range))_$(last(concert_days_range))"

filename = "concert_analysis_$(day_str)_x$(n_simulations).txt"


setting_colors = Dict('h' => :orange, 'c' => :red, 'o' => :purple, 'g' => :blue, 'm' => :brown)
const setting_labels = Dict('h' => "Household", 'c' => "SchoolClass", 'o' => "Office", 'g' => "GlobalSetting", 'm' => "Municipality")
const setting_list = ['h', 'c', 'o', 'g', 'm']

function fmt(x; digits=1)
    round(x, digits=digits)
end


function summary_stats(v)
    (
        mean=mean(v),
        std=length(v) > 1 ? std(v) : 0.0,
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
        println(io, "\n\n##############################")
        println(io, "### Concert Day $day")
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



## === Plots ===
function plot_day(day)
    ts = results_by_day[day].timeseries

    p1 = plot(title="Epidemic Curves — Day $day", xlabel="Tick", ylabel="Count")
    shaded_series!(p1,
        [ts["exposed"], ts["infectious"], ts["recovered"], ts["dead"]],
        [:blue, :red, :green, :black],
        ["Exposed", "Infectious", "Recovered", "Dead"]
    )
    


    p2 = plot(title="Cumulative Cases — Day $day", xlabel="Tick", ylabel="Count")
    shaded_series!(p2,
        [ts["cumulative_infections"], ts["cumulative_recoveries"], ts["cumulative_deaths"]],
        [:blue, :green, :black],
        ["Infections", "Recoveries", "Deaths"]
    )

    p3 = plot(title="Effective R — Day $day", xlabel="Tick", ylabel="R")
    shaded_series!(p3,
        [ts["effectiveR_rolling"], ts["effectiveR_inhh"], ts["effectiveR_outhh"]],
        [:blue, :green, :black],
        ["Overall", "In Household", "Out Household"]
    )

    p_overview = plot(p1, p2, p3, layout=(3,1), size=(800, 900), dpi=300)
    savefig(p_overview, "Concert_Project/Plots/epidemic_overview_day$(day).png")


    p4 = plot(title="Cases by Setting — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    settings = results_by_day[day].settings
    for s in setting_list
        shaded_series!(p4, [settings[s]], [setting_colors[s]], [setting_labels[s]])
    end
    savefig(p4, "Concert_Project/Plots/cases_by_setting_day$(day).png")


    gen_sit = results_by_day[day].chain.gen_sitting
    gen_sta = results_by_day[day].chain.gen_standing

    p5 = plot(title="Downstream Infections by Generation — Day $day",
        xlabel="Generation", ylabel="Infections", dpi=300)
    # for sitting
    avg_sit = mean(gen_sit, dims=2)[:]
    lo_sit = minimum(gen_sit, dims=2)[:]
    hi_sit = maximum(gen_sit, dims=2)[:]
    plot!(p5, 1:length(avg_sit), avg_sit,
        ribbon=(avg_sit .- lo_sit, hi_sit .- avg_sit),
        fillalpha=0.2, label="Sitting", color=:blue, linewidth=2)

    # for standing
    avg_sta = mean(gen_sta, dims=2)[:]
    lo_sta = minimum(gen_sta, dims=2)[:]
    hi_sta = maximum(gen_sta, dims=2)[:]
    plot!(p5, 1:length(avg_sta), avg_sta,
        ribbon=(avg_sta .- lo_sta, hi_sta .- avg_sta),
        fillalpha=0.2, label="Standing", color=:red, linewidth=2)

    savefig(p5, "Concert_Project/Plots/downstream_by_generation_day$(day).png")

end



function plot_infected_boxplot()
    groups = Int[]
    sit_values = Float64[]
    sta_values = Float64[]
    for day in concert_days_range
        raw = results_by_day[day].concert_raw
        append!(sit_values, [r.infected_sitting  for r in raw])
        append!(sta_values, [r.infected_standing for r in raw])
        append!(groups, fill(day, length(raw)))
    end

    p1 = boxplot(groups, sit_values,
        title="Infected at Concert (Sitting)", xlabel="Concert Day", ylabel="Infected",
        legend=false, dpi=300, color=:blue)

    p2 = boxplot(groups, sta_values,
        title="Infected at Concert (Standing)", xlabel="Concert Day", ylabel="Infected",
        legend=false, dpi=300, color=:red)

    p = plot(p1, p2, layout=(2,1), size=(800, 800), dpi=300)
    savefig(p, "Concert_Project/Plots/infected_at_concert_boxplot.png")
end

## === BOB Plots ===

function plot_concert_impact_by_day()
    days_vec = collect(concert_days_range)

    # --- p1: mean infected at concert ---
    means_sit = Float64[]; stds_sit = Float64[]
    means_sta = Float64[]; stds_sta = Float64[]
    for day in days_vec
        m_sit = results_by_day[day].concert[:infected_sitting]
        m_sta = results_by_day[day].concert[:infected_standing]
        push!(means_sit, m_sit.mean); push!(stds_sit, m_sit.std)
        push!(means_sta, m_sta.mean); push!(stds_sta, m_sta.std)
    end
    p1 = plot(days_vec, means_sit, ribbon=stds_sit,
        title="Mean Infected at Concert by Day",
        xlabel="Concert Day", ylabel="Infected",
        label="Sitting", color=:blue, fillalpha=0.3, linewidth=2)
    plot!(p1, days_vec, means_sta, ribbon=stds_sta,
        label="Standing", color=:red, fillalpha=0.3, linewidth=2)

    # --- p2: downstream infections ---
    sit_gen1 = Float64[]; sit_total = Float64[]
    sta_gen1 = Float64[]; sta_total = Float64[]
    for day in days_vec
        push!(sit_gen1,  mean(results_by_day[day].chain.gen_sitting[1, :]))
        push!(sta_gen1,  mean(results_by_day[day].chain.gen_standing[1, :]))
        push!(sit_total, results_by_day[day].chain.aggregated[:total_downstream_sitting].mean)
        push!(sta_total, results_by_day[day].chain.aggregated[:total_downstream_standing].mean)
    end
    p2 = plot(title="Downstream Infections by Concert Day",
        xlabel="Concert Day", ylabel="Infections")
    plot!(p2, days_vec, sit_gen1,  label="Sitting gen 1",  color=:blue, linewidth=2)
    plot!(p2, days_vec, sit_total, label="Sitting total",  color=:blue, linewidth=2, linestyle=:dash)
    plot!(p2, days_vec, sta_gen1,  label="Standing gen 1", color=:red,  linewidth=2)
    plot!(p2, days_vec, sta_total, label="Standing total", color=:red,  linewidth=2, linestyle=:dash)

    # --- combine ---
    p_overview = plot(p1, p2, layout=(2,1), size=(800, 800), dpi=300)
    savefig(p_overview, "Concert_Project/Plots/concert_impact_by_day.png")
end
    

function plot_heatmap_cumulative_infections()
    heatmap_matrix = nothing
for day in concert_days_range
    avg, _, _ = ribbon_data(results_by_day[day].timeseries["cumulative_infections"])
    if heatmap_matrix === nothing
        heatmap_matrix = avg'  # first row, transpose to make it a row vector
    else
        heatmap_matrix = vcat(heatmap_matrix, avg')  # stack rows
    end
end

days_vec = collect(concert_days_range)
n_ticks  = size(heatmap_matrix, 2)

p = heatmap(1:n_ticks, days_vec, heatmap_matrix ./ 1000,
    title  = "Mean Cumulative Infections by Concert Day",
    xlabel = "Tick",
    ylabel = "Concert Day",
    colorbar_title = "Infections (thousands)",
    color  = :viridis,
    dpi    = 300,
    yticks = (days_vec, string.(days_vec)))
savefig(p, "Concert_Project/Plots/heatmap_cumulative_infections.png")

end



## === Generate plots automatically ===
plot_infected_boxplot()

if length(concert_days_range) > 1
    plot_concert_impact_by_day()
    plot_heatmap_cumulative_infections()
end

if length(concert_days_range) == 1
    plot_day(first(concert_days_range))
end

println("\nPlots saved to Concert_Project/Plots/")
if length(concert_days_range) > 1
    println("Call plot_day(day) for detailed per-day plots, e.g. plot_day($(first(concert_days_range)))")
end