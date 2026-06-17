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

    end

end

println("Metrics saved to Concert_Project/Results/$(filename)")



## === Plots ===
function plot_day(day)
    ts = results_by_day[day].timeseries
    cl = results_by_day[day].cl_timeseries

    p1 = plot(title="Epidemic Curves — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    shaded_series!(p1,
        [ts["exposed"], ts["infectious"], ts["recovered"], ts["dead"]],
        [:blue, :red, :green, :black],
        ["Exposed", "Infectious", "Recovered", "Dead"]
    )
    savefig(p1, "Concert_Project/Plots/epidemic_curves_day$(day).png")


    p2 = plot(title="Cumulative Cases — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    shaded_series!(p2,
        [ts["cumulative_infections"], ts["cumulative_recoveries"], ts["cumulative_deaths"]],
        [:blue, :green, :black],
        ["Infections", "Recoveries", "Deaths"]
    )
    savefig(p2, "Concert_Project/Plots/cumulative_cases_day$(day).png")

    p3 = plot(title="Effective R — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    shaded_series!(p3,
        [ts["effectiveR_rolling"], ts["effectiveR_inhh"], ts["effectiveR_outhh"]],
        [:blue, :green, :black],
        ["Overall", "In Household", "Out Household"]
    )
    savefig(p3, "Concert_Project/Plots/Effective_R_day$(day).png")


    p4 = plot(title="Cases by Setting — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    settings = results_by_day[day].settings
    for s in setting_list
        shaded_series!(p4, [settings[s]], [setting_colors[s]], [setting_labels[s]])
    end
    savefig(p4, "Concert_Project/Plots/cases_by_setting_day$(day).png")

    p5 = plot(title="Total infectios — Day $day", xlabel="Tick", ylabel="Count", dpi=300)
    shaded_series!(p5,
        [cl["total_infectious"], cl["infectious_sitting"], cl["infectious_standing"]],
        [:blue, :green, :black],
        ["Total", "Sitting", "Standing"]
    )
    savefig(p5, "Concert_Project/Plots/infectious_over_time_day$(day).png")

end


function plot_infected_boxplot()
    groups = Int[]
    values = Float64[]
    for day in concert_days_range
        raw = results_by_day[day].concert_raw
        infected = [r.infected_sitting + r.infected_standing for r in raw]
        append!(values, infected)
        append!(groups, fill(day, length(infected)))
    end
    p = boxplot(groups, values,
        title = "Infected at Concert by Day", xlabel = "Concert Day", ylabel = "Infected",
        legend = false, dpi = 300)
    savefig(p, "Concert_Project/Plots/infected_at_concert_boxplot.png")
end


function plot_mean_infected_by_day()
    days_vec = collect(concert_days_range)
    means = Float64[]
    stds  = Float64[]
    for day in days_vec
        m_sit = results_by_day[day].concert[:infected_sitting]
        m_sta = results_by_day[day].concert[:infected_standing]
        push!(means, m_sit.mean + m_sta.mean)
        push!(stds,  sqrt(m_sit.std^2 + m_sta.std^2))  # combine variances
    end

    p = plot(days_vec, means, ribbon = stds,
        title = "Mean Infected at Concert by Day", xlabel = "Concert Day", ylabel = "Infected",
        fillalpha = 0.3, color = :blue, linewidth = 2, dpi = 300, legend = false)
    savefig(p, "Concert_Project/Plots/mean_infected_by_day.png")
end



function plot_grand_average()
    all_exposed    = Vector{Vector{Float64}}()
    all_infectious = Vector{Vector{Float64}}()
    all_recovered  = Vector{Vector{Float64}}()
    all_dead       = Vector{Vector{Float64}}()
    cumulative_infections    = Vector{Vector{Float64}}()
    cumulative_recoveries    = Vector{Vector{Float64}}()
    cumulative_deaths   = Vector{Vector{Float64}}()

    for day in concert_days_range
        ts = results_by_day[day].timeseries
        append!(all_exposed,    ts["exposed"])
        append!(all_infectious, ts["infectious"])
        append!(all_recovered, ts["recovered"])
        append!(all_dead, ts["dead"])

        append!(cumulative_infections, ts["cumulative_infections"])
append!(cumulative_recoveries, ts["cumulative_recoveries"])
append!(cumulative_deaths, ts["cumulative_deaths"])
    end

    p1 = plot(title = "Grand Average Epidemic Curves", xlabel = "Tick", ylabel = "Count", dpi = 300)
    shaded_series!(p1, [all_exposed, all_infectious, all_recovered, all_dead],
        [:blue, :red, :green, :black], ["Exposed", "Infectious", "Recovered", "Dead"])
    savefig(p1, "Concert_Project/Plots/grand_average_epidemic_curves.png")

    p2 = plot(title = "Grand Average Cumulative Cases", xlabel = "Tick", ylabel = "Count", dpi = 300)
    shaded_series!(p2, [cumulative_infections, cumulative_recoveries, cumulative_deaths],
        [:blue, :green, :black], ["Cumulative infections", "Cumulative recoveries", "Cumulative deaths"])
    savefig(p2, "Concert_Project/Plots/grand_average_cumulative_cases.png")

end

## === Generate plots automatically ===
plot_infected_boxplot()

if length(concert_days_range) > 1
    plot_mean_infected_by_day()
    plot_grand_average()
end

if length(concert_days_range) == 1
    plot_day(first(concert_days_range))
end

println("\nPlots saved to Concert_Project/Plots/")
if length(concert_days_range) > 1
    println("Call plot_day(day) for detailed per-day plots, e.g. plot_day($(first(concert_days_range)))")
end