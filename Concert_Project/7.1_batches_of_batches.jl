## === Global Configuration ===
# --- Concert Settings ---
# Note: concert_date is not const here as it changes each batch
concert_date = 1

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

# --- Batch of Batches Settings ---
const n_simulations      = 100
const concert_days_range = 1:1:100




## === Derived Constants ===
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total




## === Include Custom Modules ===
include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Setting Plot Helpers ===
const setting_colors = Dict('h' => :orange, 'c' => :red, 'o' => :purple, 'g' => :blue, 'm' => :brown)
const setting_labels = Dict('h' => "Household", 'c' => "SchoolClass", 'o' => "Office", 'g' => "GlobalSetting", 'm' => "Municipality")




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




## === Storage ===
infected_distributions = Dict{Int, Vector{Float64}}()
summary_by_day         = Dict{Int, NamedTuple}()

# Per-day per-tick storage (for multi-day plots)
per_day_tick_general  = Dict{Int, Dict{String, Vector{Vector{Float64}}}}()
per_day_tick_settings = Dict{Int, Dict{Char, Vector{Vector{Float64}}}}()

for day in concert_days_range
    infected_distributions[day] = Float64[]
end




## === Run Batch of Batches ===
for day in concert_days_range
    println("\n=== Concert day $day of $(last(concert_days_range)) ===")

    global concert_date = day
    infected_at_concert_v = Float64[]

    # Per-day storage (reset each day)
    all_tick_cases_general_exposed    = Vector{Vector{Float64}}()
    all_tick_cases_general_infectious = Vector{Vector{Float64}}()
    all_tick_cases_general_recovered  = Vector{Vector{Float64}}()
    all_tick_cases_general_dead       = Vector{Vector{Float64}}()
    all_tick_cases = Dict{Char, Vector{Vector{Float64}}}()

    for i in 1:n_simulations
        sim = Simulation(
            configfile   = "Concert_Project/toml/config_concert_covid.toml",
            population   = "Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
            settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
            global_setting_contacts = ConcertContacts(),
            label = "Concert simulation day $day run $i"
        )

        cl = CustomLogger(concert_day_stats = concert_infectious)
        customlogger!(sim, cl)
        run!(sim)

        # --- Infected at concert count ---
        inf_logger         = dataframe(infectionlogger(sim))
        global_cases_count = 0
        for row in eachrow(inf_logger)
            if row.tick == concert_date && row.setting_type == 'g'
                global_cases_count += 1
            end
        end
        push!(infected_at_concert_v, global_cases_count)

        # --- Per-tick general data ---
        rd = ResultData(sim; style = "ConcertRD")
        tick_cases_sim = rd.data["dataframes"]["tick_cases"]
        push!(all_tick_cases_general_exposed,    Float64.(tick_cases_sim[!, "exposed_cnt"]))
        push!(all_tick_cases_general_infectious, Float64.(tick_cases_sim[!, "infectious_cnt"]))
        push!(all_tick_cases_general_recovered,  Float64.(tick_cases_sim[!, "recovered_cnt"]))
        push!(all_tick_cases_general_dead,       Float64.(tick_cases_sim[!, "dead_cnt"]))

        # --- Per-tick setting data ---
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

    # Store distribution and summary for this day
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

    # Store per-tick data for multi-day plots
    per_day_tick_general[day] = Dict(
        "exposed"    => all_tick_cases_general_exposed,
        "infectious" => all_tick_cases_general_infectious,
        "recovered"  => all_tick_cases_general_recovered,
        "dead"       => all_tick_cases_general_dead
    )
    per_day_tick_settings[day] = all_tick_cases

    println("  Mean infected at concert: $(round(mean(infected_at_concert_v), digits=1))  Std: $(round(std(infected_at_concert_v), digits=1))")
end




## === Print Summary Table ===
println("\n=== Summary by Concert Day ===")
println(rpad("Day", 5), " | ",
        rpad("Mean", 8), " | ",
        rpad("Std", 8), " | ",
        rpad("CV%", 8), " | ",
        rpad("Min", 6), " | ",
        rpad("P25", 6), " | ",
        rpad("Median", 8), " | ",
        rpad("P75", 6), " | ",
        rpad("P90", 6), " | ",
        rpad("P95", 6), " | ",
        "Max")
println("-"^95)
for day in concert_days_range
    s = summary_by_day[day]
    println(rpad(day, 5), " | ",
            rpad(round(s.mean,   digits=1), 8), " | ",
            rpad(round(s.std,    digits=1), 8), " | ",
            rpad(round(s.cv,     digits=1), 8), " | ",
            rpad(round(s.min,    digits=1), 6), " | ",
            rpad(round(s.p25,    digits=1), 6), " | ",
            rpad(round(s.median, digits=1), 8), " | ",
            rpad(round(s.p75,    digits=1), 6), " | ",
            rpad(round(s.p90,    digits=1), 6), " | ",
            rpad(round(s.p95,    digits=1), 6), " | ",
            round(s.max, digits=1))
end




## === Plot: Boxplot of infected at concert by day ===
days = collect(concert_days_range)
data = [infected_distributions[day] for day in days]

gp = boxplot(
    repeat(days, inner = n_simulations),
    vcat(data...),
    title     = "Distribution of Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Infections at Concert",
    legend    = false,
    dpi       = 300,
    color     = :blue,
    fillalpha = 0.5,
    linewidth = 1
)
png(gp, "Concert_Project/Plots/BOB_infections_at_concert_boxplot.png")




## === Plot: Violin of infected at concert by day ===
gp1 = violin(
    repeat(days, inner = n_simulations),
    vcat(data...),
    title     = "Distribution of Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Infections at Concert",
    legend    = false,
    dpi       = 300,
    color     = :blue,
    fillalpha = 0.5,
    linewidth = 1
)
png(gp1, "Concert_Project/Plots/BOB_infections_at_concert_violin.png")




## === Plot: Mean infected at concert by day ===
gp2 = plot(days,
    [summary_by_day[day].mean for day in days],
    ribbon    = [summary_by_day[day].std for day in days],
    fillalpha = 0.3,
    title     = "Mean Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Mean Infections at Concert",
    label     = "Mean ± Std",
    color     = :blue,
    linewidth = 2,
    dpi       = 300
)
png(gp2, "Concert_Project/Plots/BOB_infections_at_concert_mean_by_day.png")




## === Helper: compute mean ribbon for a list of run vectors ===
function ribbon_data(series_list)
    mat = hcat(series_list...)
    avg = mean(mat, dims=2)[:]
    lo  = minimum(mat, dims=2)[:]
    hi  = maximum(mat, dims=2)[:]
    return avg, lo, hi
end




## === Color gradient across days ===
days_vec      = collect(concert_days_range)
n_days        = length(days_vec)
grad          = cgrad([:blue, :red], n_days)
day_color_map = Dict(day => grad[i] for (i, day) in enumerate(days_vec))




## === Plot A: General — one banded line per concert day ===
using StatsPlots
pA_exp = plot(title = "Exposed per Day by Concert Day",    xlabel = "Day", ylabel = "Individuals", dpi = 300, legend = :topright)
pA_inf = plot(title = "Infectious per Day by Concert Day", xlabel = "Day", ylabel = "Individuals", dpi = 300, legend = :topright)
pA_rec = plot(title = "Recovered per Day by Concert Day",  xlabel = "Day", ylabel = "Individuals", dpi = 300, legend = :topright)
pA_ded = plot(title = "Dead per Day by Concert Day",       xlabel = "Day", ylabel = "Individuals", dpi = 300, legend = :topright)

for day in concert_days_range
    c = day_color_map[day]
    lbl = "Day $day"
    for (p_ax, key) in [(pA_exp, "exposed"), (pA_inf, "infectious"), (pA_rec, "recovered"), (pA_ded, "dead")]
        avg, lo, hi = ribbon_data(per_day_tick_general[day][key])
        plot!(p_ax, 1:length(avg), avg,
            ribbon    = (avg .- lo, hi .- avg),
            fillalpha = 0.15,
            label     = lbl,
            color     = c,
            linewidth = 1.5
        )
    end
end

gpA = plot(pA_exp, pA_inf, pA_rec, pA_ded,
    layout        = (2, 2),
    size          = (1200, 800),
    titlefontsize = 10
)
png(gpA, "Concert_Project/Plots/BOB_epidemic_curves_by_concert_day.png")




## === Plot B: General — single average banded line (averaged across all days) ===
function grand_average_ribbon(key)
    all_avgs = Vector{Vector{Float64}}()
    for day in concert_days_range
        mat = hcat(per_day_tick_general[day][key]...)
        push!(all_avgs, mean(mat, dims=2)[:])
    end
    grand_mat = hcat(all_avgs...)
    return mean(grand_mat, dims=2)[:], minimum(grand_mat, dims=2)[:], maximum(grand_mat, dims=2)[:]
end

pB = plot(title = "Cases per Day — Grand Average Across All Concert Days",
          xlabel = "Day", ylabel = "Individuals", dpi = 300)
for (key, color, label) in [
        ("exposed",    :blue,   "Exposed"),
        ("infectious", :orange, "Became Infectious"),
        ("recovered",  :green,  "Recovered"),
        ("dead",       :black,  "Died")]
    avg, lo, hi = grand_average_ribbon(key)
    plot!(pB, 1:length(avg), avg,
        ribbon    = (avg .- lo, hi .- avg),
        fillalpha = 0.2,
        label     = label,
        color     = color,
        linewidth = 2
    )
end
png(pB, "Concert_Project/Plots/BOB_epidemic_curves_grand_average.png")




## === Plot C: Settings — one banded line per concert day ===
setting_list = ['h', 'c', 'o', 'g', 'm']
setting_plots_C = Dict(s => plot(
    title     = "$(setting_labels[s]) — Infections per Day by Concert Day",
    xlabel    = "Day",
    ylabel    = "Individuals",
    dpi       = 300,
    legend    = :topright
) for s in setting_list)

for day in concert_days_range
    c = day_color_map[day]
    lbl = "Day $day"
    for setting in setting_list
        if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
            avg, lo, hi = ribbon_data(per_day_tick_settings[day][setting])
            plot!(setting_plots_C[setting], 1:length(avg), avg,
                ribbon    = (avg .- lo, hi .- avg),
                fillalpha = 0.15,
                label     = lbl,
                color     = c,
                linewidth = 1.5
            )
        end
    end
end

gpC = plot(
    [setting_plots_C[s] for s in setting_list]...,
    layout        = (3, 2),
    size          = (1200, 1000),
    titlefontsize = 9
)
png(gpC, "Concert_Project/Plots/BOB_setting_infections_by_concert_day.png")




## === Plot D: Settings — single average banded line (averaged across all days) ===
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

pD = plot(title = "Infections per Day by Setting — Grand Average Across All Concert Days",
          xlabel = "Day", ylabel = "Individuals", dpi = 300)
for setting in setting_list
    avg, lo, hi = grand_average_ribbon_setting(setting)
    isempty(avg) && continue
    plot!(pD, 1:length(avg), avg,
        ribbon    = (avg .- lo, hi .- avg),
        fillalpha = 0.3,
        label     = setting_labels[setting],
        color     = setting_colors[setting],
        linewidth = 2
    )
end
png(pD, "Concert_Project/Plots/BOB_setting_infections_grand_average.png")




## === On-Demand Single-Day Plots ===
# Call plot_day(25) after the simulation to get the two plots for any specific concert day.
function plot_day(day::Int)
    if !haskey(per_day_tick_general, day)
        println("No data for concert day $day. Available days: $(collect(concert_days_range))")
        return
    end

    # Epidemic curves for this day
    pE = plot(title = "Cases per Day — Concert Day $day",
              xlabel = "Day", ylabel = "Individuals", dpi = 300)
    shaded_series!(pE,
        [per_day_tick_general[day]["exposed"],
         per_day_tick_general[day]["infectious"],
         per_day_tick_general[day]["recovered"],
         per_day_tick_general[day]["dead"]],
        [:blue, :orange, :green, :black],
        ["Exposed", "Became Infectious", "Recovered", "Died"]
    )
    png(pE, "Concert_Project/Plots/BOB_epidemic_curves_day$(day).png")
    println("Saved: Concert_Project/Plots/BOB_epidemic_curves_day$(day).png")

    # Setting infections for this day
    pF = plot(title = "Infections per Day by Setting — Concert Day $day",
              xlabel = "Day", ylabel = "Individuals", dpi = 300)
    for setting in setting_list
        if haskey(per_day_tick_settings[day], setting) && !isempty(per_day_tick_settings[day][setting])
            avg, lo, hi = ribbon_data(per_day_tick_settings[day][setting])
            plot!(pF, 1:length(avg), avg,
                ribbon    = (avg .- lo, hi .- avg),
                fillalpha = 0.3,
                label     = setting_labels[setting],
                color     = setting_colors[setting],
                linewidth = 2
            )
        end
    end
    png(pF, "Concert_Project/Plots/BOB_setting_infections_day$(day).png")
    println("Saved: Concert_Project/Plots/BOB_setting_infections_day$(day).png")
end

# Example usage (uncomment or call interactively after the simulation):
# plot_day(25)
# plot_day(50)




## === Save Summary Table ===
open("Concert_Project/Results/BOB_summary.txt", "w") do f
    println(f, "\n=== Summary by Concert Day ===")
    println(f, rpad("Day", 5), " | ",
            rpad("Mean", 8), " | ",
            rpad("Std", 8), " | ",
            rpad("CV%", 8), " | ",
            rpad("Min", 6), " | ",
            rpad("P25", 6), " | ",
            rpad("Median", 8), " | ",
            rpad("P75", 6), " | ",
            rpad("P90", 6), " | ",
            rpad("P95", 6), " | ",
            "Max")
    println(f, "-"^95)
    for day in concert_days_range
        s = summary_by_day[day]
        println(f, rpad(day, 5), " | ",
                rpad(round(s.mean,   digits=1), 8), " | ",
                rpad(round(s.std,    digits=1), 8), " | ",
                rpad(round(s.cv,     digits=1), 8), " | ",
                rpad(round(s.min,    digits=1), 6), " | ",
                rpad(round(s.p25,    digits=1), 6), " | ",
                rpad(round(s.median, digits=1), 8), " | ",
                rpad(round(s.p75,    digits=1), 6), " | ",
                rpad(round(s.p90,    digits=1), 6), " | ",
                rpad(round(s.p95,    digits=1), 6), " | ",
                round(s.max, digits=1))
    end
end

## END
println("\nEND SIMULATION 7 BATCH OF BATCHES")