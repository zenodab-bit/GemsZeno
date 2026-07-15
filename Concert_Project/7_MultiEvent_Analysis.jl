using StatsPlots, Dates

ENV["GKSwstype"] = "100"  # headless mode for server

# === Helper functions ===

function fmt(x; digits=2)
    round(x, digits=digits)
end

function summary_stats(v)
    (
        mean   = mean(v),
        std    = length(v) > 1 ? std(v) : 0.0,
        min    = minimum(v),
        p25    = quantile(v, 0.25),
        median = median(v),
        p75    = quantile(v, 0.75),
        max    = maximum(v)
    )
end

function print_table_header(io)
    println(io, rpad("Metric", 20), " | ",
        rpad("Mean", 9), " | ", rpad("Std", 9), " | ",
        rpad("Min", 9), " | ", rpad("P25", 9), " | ",
        rpad("Median", 9), " | ", rpad("P75", 9), " | ", "Max")
    println(io, "-"^100)
end

function print_metric_row(io, label, m)
    println(io, rpad(label, 20), " | ",
        rpad(fmt(m.mean), 9), " | ", rpad(fmt(m.std), 9), " | ",
        rpad(fmt(m.min), 9), " | ", rpad(fmt(m.p25), 9), " | ",
        rpad(fmt(m.median), 9), " | ", rpad(fmt(m.p75), 9), " | ",
        fmt(m.max))
end

function add_event_vlines!(p, events)
    for event in events
        vline!(p, [event.date],
               linestyle=:dash,
               color=:black,
               label="Event $(event.id) (day $(event.date))",
               linewidth=1.5)
    end
end


# === Text metrics ===

function print_metrics(aggregated, events, bd, run_validation, run_folder)
    filename = "$run_folder/multievent_analysis.txt"

    open(filename, "w") do io
        println(io, "=== MultiEvent Analysis ===")
        println(io, "Simulations: $n_simulations")
        println(io, "Events: $(length(events))")

        # --- Global epidemic metrics ---
        println(io, "\n--- Global Epidemic Metrics ---")
        println(io, "Total infections: $(total_infections(bd))")
        println(io, "Attack rate:      $(attack_rate(bd))")
        println(io, "R0:               $(r0(bd))")

        # --- Per event metrics ---
        for event in events
            println(io, "\n\n##############################")
            println(io, "### Event $(event.id) — Day $(event.date) — n=$(event.n)")
            println(io, "##############################")

            print_table_header(io)
            metrics = aggregated[event.id]
            print_metric_row(io, "Susceptible",       metrics[:susceptible])
            print_metric_row(io, "Infectious",        metrics[:infectious])
            print_metric_row(io, "Exposed",           metrics[:exposed])
            print_metric_row(io, "Recovered",         metrics[:recovered])
            print_metric_row(io, "Dead",              metrics[:dead])
            print_metric_row(io, "Same day other",    metrics[:same_day_other])
            print_metric_row(io, "Infected at event", metrics[:infected_at_event])

            infection_rate = metrics[:infected_at_event].mean / event.n * 100
            println(io, "\nInfection rate: $(fmt(infection_rate))%")

            if run_validation
                println(io, "\nValidation:")
                print_table_header(io)
                print_metric_row(io, "Expected", metrics[:expected])
                print_metric_row(io, "Std",      metrics[:std])
                print_metric_row(io, "Z-score",  metrics[:z_score])
            end
        end
    end

    println("Metrics saved to $filename")
end


# === Plots ===

function plot_epidemic_overview(bd, events, run_folder)
    p1 = gemsplot(bd, type = :TickCases)
    add_event_vlines!(p1, events)

    p2 = gemsplot(bd, type = :CumulativeCases)
    add_event_vlines!(p2, events)

    p3 = gemsplot(bd, type = :EffectiveReproduction)
    add_event_vlines!(p3, events)

    p_overview = plot(p1, p2, p3, layout=(3, 1), size=(800, 900), dpi=300)
    savefig(p_overview, "$run_folder/Plots/epidemic_overview.png")
    println("Saved: epidemic_overview")
end


function plot_cases_by_setting(bd, events, run_folder)
    setting_colors = Dict(
        'h' => :orange,
        'c' => :red,
        'o' => :purple,
        'g' => :blue,
        'm' => :brown,
        '?' => :gray
    )
    setting_labels = Dict(
        'h' => "Household",
        'c' => "SchoolClass",
        'o' => "Office",
        'g' => "GlobalSetting",
        'm' => "Municipality",
        '?' => "Initial"
    )

    all_setting_cases = Dict{Char, Vector{Vector{Float64}}}()

    for rd in runs(bd)
        inf_log = infections(rd)
        n_ticks = maximum(inf_log.tick)
        tick_setting = combine(groupby(inf_log, [:tick, :setting_type]), nrow => :daily_cases)

        for s in keys(setting_labels)
            rows = filter(r -> r.setting_type == s, tick_setting)
            series = zeros(Float64, n_ticks + 1)
            for row in eachrow(rows)
                series[row.tick + 1] = Float64(row.daily_cases)
            end
            if !haskey(all_setting_cases, s)
                all_setting_cases[s] = Vector{Vector{Float64}}()
            end
            push!(all_setting_cases[s], series)
        end
    end

    p = plot(title="Cases by Setting", xlabel="Tick", ylabel="Daily Cases", dpi=300)
    for (s, series_list) in all_setting_cases
        isempty(series_list) && continue
        mat = hcat(series_list...)
        avg = mean(mat, dims=2)[:]
        lo  = minimum(mat, dims=2)[:]
        hi  = maximum(mat, dims=2)[:]
        any(avg .> 0) || continue
        plot!(p, 0:length(avg)-1, avg,
            ribbon=(avg .- lo, hi .- avg),
            fillalpha=0.2,
            label=setting_labels[s],
            color=setting_colors[s],
            linewidth=2)
    end
    add_event_vlines!(p, events)
    savefig(p, "$run_folder/Plots/cases_by_setting.png")
    println("Saved: cases_by_setting")
end


function plot_event_seir(aggregated, events, run_folder)
    fields = [:susceptible, :infectious, :exposed, :recovered, :dead]
    colors = [:green, :red, :blue, :gray, :black]

    for event in events
        metrics = aggregated[event.id]
        values = [metrics[f].mean for f in fields]

        p = bar(string.(fields), values,
            color = colors,
            title = "SEIR State — Event $(event.id) Day $(event.date)",
            xlabel = "Compartment",
            ylabel = "Count",
            legend = false,
            dpi = 300)
        savefig(p, "$run_folder/Plots/seir_$(event.id).png")
        println("Saved: seir_$(event.id)")
    end
end


function plot_infected_boxplot(event_results, events, run_folder)
    event_ids = [e.id for e in events]
    values_per_event = [[r[e.id].infected_at_event for r in event_results] for e in events]

    p = plot(title="Infected at Event", xlabel="Event", ylabel="Infected", dpi=300)
    for (i, vals) in enumerate(values_per_event)
        boxplot!(p, [event_ids[i]], vals, label=event_ids[i], legend=true)
    end
    savefig(p, "$run_folder/Plots/infected_boxplot.png")
    println("Saved: infected_boxplot")
end


# === Auto-generate ===
print_metrics(aggregated, events, bd, run_validation, run_folder)
plot_epidemic_overview(bd, events, run_folder)
plot_cases_by_setting(bd, events, run_folder)
plot_event_seir(aggregated, events, run_folder)
plot_infected_boxplot(event_results, events, run_folder)

println("\nAnalysis complete. Results saved to $run_folder")