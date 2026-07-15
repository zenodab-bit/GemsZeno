import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using GEMS, Parameters, DataFrames, Distributions, CSV,
      CategoricalArrays, JLD2, Random, StatsBase, Plots, StatsPlots, Dates

include("0_MultiEvent_Config.jl")
include("2_MultiEvent_Population.jl")
include("3_MultiEvent_Contacts.jl")
include("4_MultiEvent_Transmission.jl")
include("6_MultiEvent_Helpers.jl")

n_simulations = 1
rng = Xoshiro(1234)
run_validation = false

# --- Sample events from categories ---
events = sample_events(event_config, rng)

println("\n=== Sampled Events ===")
for e in events
    println("Event $(e.id) — date: $(e.date), n: $(e.n), contacts: $(e.mean_contacts)")
end

# --- Population setup ---
people, age_groups, sex_levels = prepare_population(event_config)
assign_events!(people, events, event_config, rng)
validate_assignment(people, events)

# --- Build transmission function with event dates ---
transmission_func = SettingRate(
    general_rate  = event_config.transmission_rate,
    event_dates   = Set{Int16}(Int16(e.date) for e in events)
)

# --- Run batch ---
b = Batch(
    n_runs               = n_simulations,
    configfile           = joinpath(@__DIR__, "toml", "config_concert_covid.toml"),
    population           = people,
    settingsfile         = joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"),
    ind_extension        = [:event_ids, :section_ids, :mean_event_contacts, :event_dates],
    transmission_function = transmission_func,
    label                = "MultiEvent simulation"
)
bd = BatchData(b; rd_style = "EssentialResultData")

# --- Per-event analysis ---
event_results = Vector{Any}()
for rd in runs(bd)
    inf_log = infections(rd)
    result = analyze_event_population(inf_log, people, events, run_validation)
    push!(event_results, result)
end

aggregated = aggregate_event_results(event_results)

run_folder = "Concert_Project/Results/run_$(n_simulations)sims_$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM"))"
mkpath(run_folder)
mkpath("$run_folder/Plots")

println("\nSimulation complete.")
include("7_MultiEvent_Analysis.jl")