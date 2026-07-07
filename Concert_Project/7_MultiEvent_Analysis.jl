using StatsPlots

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

function add_event_vlines!(p, event_config)
    for event in event_config.events
        vline!(p, [event.date], 
               linestyle=:dash, 
               color=:black, 
               label="Event $(event.id) (day $(event.date))",
               linewidth=1.5)
    end
end


# === Text metrics ===

function print_metrics(aggregated, event_config, bd, run_validation)
    filename = "Concert_Project/Results/multievent_analysis_x$(n_simulations).txt"
    
    open(filename, "w") do io
        println(io, "=== MultiEvent Analysis ===")
        println(io, "Simulations: $n_simulations")
        println(io, "Events: $(length(event_config.events))")

        # --- Global epidemic metrics ---
        println(io, "\n--- Global Epidemic Metrics ---")
        println(io, "Total infections: $(total_infections(bd))")
        println(io, "Attack rate:      $(attack_rate(bd))")
        println(io, "R0:               $(r0(bd))")

        # --- Per event metrics ---
        for event in event_config.events
            println(io, "\n\n##############################")
            println(io, "### Event $(event.id) — Day $(event.date)")
            println(io, "##############################")

            for section in event.sections
                println(io, "\n--- Section $(section.id) ---")
                print_table_header(io)

                metrics = aggregated[event.id][section.id]
                print_metric_row(io, "Susceptible",      metrics[:susceptible])
                print_metric_row(io, "Infectious",       metrics[:infectious])
                print_metric_row(io, "Exposed",          metrics[:exposed])
                print_metric_row(io, "Recovered",        metrics[:recovered])
                print_metric_row(io, "Dead",             metrics[:dead])
                print_metric_row(io, "Same day other",   metrics[:same_day_other])
                print_metric_row(io, "Infected at event",metrics[:infected_at_event])

                infection_rate = metrics[:infected_at_event].mean / section.n * 100
                println(io, "\nInfection rate: $(fmt(infection_rate))%")

                if run_validation
                    println(io, "\nValidation:")
                    print_table_header(io)
                    print_metric_row(io, "Expected",  metrics[:expected])
                    print_metric_row(io, "Std",       metrics[:std])
                    print_metric_row(io, "Z-score",   metrics[:z_score])
                end
            end
        end
    end

    println("Metrics saved to $filename")
end


# === Plots ===

function plot_epidemic_overview(bd, event_config)
    p1 = gemsplot(bd, type = :TickCases)
    add_event_vlines!(p1, event_config)

    p2 = gemsplot(bd, type = :CumulativeCases)
    add_event_vlines!(p2, event_config)

    p3 = gemsplot(bd, type = :EffectiveReproduction)
    add_event_vlines!(p3, event_config)

    p_overview = plot(p1, p2, p3, layout=(3, 1), size=(800, 900), dpi=300)
    savefig(p_overview, "Concert_Project/Plots/multievent_epidemic_overview.png")
    println("Saved: epidemic_overview")
end


function plot_cases_by_setting(bd, event_config)
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

    # collect cases by setting across all runs
    all_setting_cases = Dict{Char, Vector{Vector{Float64}}}()

    for rd in runs(bd)
        inf_log = infections(rd)
        n_ticks = maximum(inf_log.tick)
        tick_setting = combine(groupby(inf_log, [:tick, :setting_type]), nrow => :daily_cases)

        for s in keys(setting_labels)
            rows = filter(r -> r.setting_type == s, tick_setting)
            series = zeros(Float64, n_ticks)
            for row in eachrow(rows)
                series[row.tick] = Float64(row.daily_cases)
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
        plot!(p, 1:length(avg), avg,
            ribbon=(avg .- lo, hi .- avg),
            fillalpha=0.2,
            label=setting_labels[s],
            color=setting_colors[s],
            linewidth=2)
    end
    add_event_vlines!(p, event_config)
    savefig(p, "Concert_Project/Plots/multievent_cases_by_setting.png")
    println("Saved: cases_by_setting")
end


function plot_event_seir(aggregated, event_config)
    for event in event_config.events
        section_ids = [s.id for s in event.sections]
        fields = [:susceptible, :infectious, :exposed, :recovered, :dead]
        colors = [:green, :red, :blue, :gray, :black]

        p = groupedbar(
            repeat(section_ids, inner=length(fields)),
            [aggregated[event.id][sid][f].mean for sid in section_ids for f in fields],
            group = repeat(string.(fields), outer=length(section_ids)),
            title = "SEIR State at Event $(event.id) — Day $(event.date)",
            xlabel = "Section",
            ylabel = "Count",
            color = repeat(colors, outer=length(section_ids)),
            dpi = 300
        )
        savefig(p, "Concert_Project/Plots/multievent_seir_event$(event.id).png")
        println("Saved: seir_event$(event.id)")
    end
end


function plot_infected_boxplot(event_results, event_config)
    for event in event_config.events
        section_ids = [s.id for s in event.sections]
        
        p = plot(title="Infected at Event $(event.id)", 
                 xlabel="Section", ylabel="Infected", dpi=300)
        
        for sid in section_ids
            values = Float64[r[event.id][sid].infected_at_event for r in event_results]
            boxplot!(p, [sid], values, label=sid, legend=true)
        end
        
        savefig(p, "Concert_Project/Plots/multievent_infected_boxplot_event$(event.id).png")
        println("Saved: infected_boxplot_event$(event.id)")
    end
end


function plot_summary(aggregated, event_config)
    length(event_config.events) == 1 && return  # skip if only one event

    event_ids = [string(e.id) for e in event_config.events]
    
    for section_label in [s.id for s in event_config.events[1].sections]
        infected_means = Float64[]
        infected_stds  = Float64[]

        for event in event_config.events
            if haskey(aggregated[event.id], section_label)
                push!(infected_means, aggregated[event.id][section_label][:infected_at_event].mean)
                push!(infected_stds,  aggregated[event.id][section_label][:infected_at_event].std)
            end
        end

        p = bar(event_ids, infected_means,
            yerror=infected_stds,
            title="Infected at Event — Section $section_label",
            xlabel="Event", ylabel="Mean Infected",
            legend=false, dpi=300)
        savefig(p, "Concert_Project/Plots/multievent_summary_section$(section_label).png")
        println("Saved: summary_section$section_label")
    end
end


# === Auto-generate ===
print_metrics(aggregated, event_config, bd, run_validation)
plot_epidemic_overview(bd, event_config)
plot_cases_by_setting(bd, event_config)
plot_event_seir(aggregated, event_config)
plot_infected_boxplot(event_results, event_config)
plot_summary(aggregated, event_config)

println("\nAnalysis complete. Results saved to Concert_Project/Results/ and Concert_Project/Plots/")