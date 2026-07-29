ENV["GKSwstype"] = "100"

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using GEMS, Parameters, DataFrames, Distributions, CSV,
    CategoricalArrays, JLD2, Random, StatsBase, Plots, StatsPlots, Dates, TOML
using Random: Xoshiro, shuffle

# === Includes ===
include("Structs.jl")
include("1_UserConfig.jl")
include("Population.jl")
include("Contacts.jl")
include("Transmission.jl")
include("Helpers.jl")

# === Run ===
n_simulations = 1
run_validation = true

events = sample_events(event_config, rng)
sort!(events, by = e -> (e.date, e.category_id, e.draw_id, e.section_id))

println("\n=== Sampled Events ===")
for e in events
    println("Event $(e.id) ($(e.name)) — date: $(e.date), n: $(e.n), contacts: $(e.mean_contacts)")
end

sim_length = config["Simulation"]["StopCriterion"]["parameters"]["limit"]

for e in events
    if e.date > sim_length
        @warn "Event $(e.id) on day $(e.date) is beyond simulation length ($sim_length). Results will be inaccurate."
    end
end

people, age_groups, sex_levels = prepare_population(event_config, rng)
attendees = assign_events!(people, events, event_config, rng)

transmission_func = SettingRate(
    general_rate = general_rate,
    event_dates = Set{Int16}(Int16(e.date) for e in events)
)

b = Batch(
    n_runs = n_simulations,
    configfile = joinpath(@__DIR__, "config_concert_covid.toml"),
    population = people,
    settingsfile = joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"),
    ind_extension = [:category_ids, :draw_ids, :section_ids, :mean_event_contacts, :std_event_contacts, :event_dates, :transmission_prob],
    transmission_function = transmission_func,
    label = "MultiEvent simulation"
)
bd = BatchData(b; rd_style = "EssentialResultData")

event_results = Vector{Dict{String,EventCounts}}()
for rd in runs(bd)
    inf_log = infections(rd)
    result = analyze_event_population(inf_log, people, events, attendees)
    push!(event_results, result)
end

aggregated = aggregate_event_results(event_results)

run_folder = "Results/run_$(n_simulations)sims_$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM"))"
mkpath(run_folder)

println("\nSimulation complete.")
include("Analysis.jl")

if run_validation
    include("Validation.jl")
end


println("End Interface")