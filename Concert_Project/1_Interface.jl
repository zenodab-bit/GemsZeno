import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using GEMS, Parameters, DataFrames, Distributions, CSV,
    CategoricalArrays, JLD2, Random, StatsBase, Plots, StatsPlots, Dates, TOML

# === Includes ===
include("2_Structs.jl")
include("0_UserConfig.jl")
include("3_Population.jl")
include("4_Contacts.jl")
include("5_Transmission.jl")
include("6_Helpers.jl")

# === Run ===
n_simulations = 2
run_validation = false

events = sample_events(event_config, rng)

println("\n=== Sampled Events ===")
for e in events
    println("Event $(e.id) ($(e.name)) — date: $(e.date), n: $(e.n), contacts: $(e.mean_contacts)")
end

config = TOML.parsefile(joinpath(@__DIR__, "config_concert_covid.toml"))
sim_length = config["Simulation"]["StopCriterion"]["parameters"]["limit"]

for e in events
    if e.date > sim_length
        @warn "Event $(e.id) on day $(e.date) is beyond simulation length ($sim_length). Results will be inaccurate."
    end
end

people, age_groups, sex_levels = prepare_population(event_config, rng)
assign_events!(people, events, event_config, rng)

transmission_func = SettingRate(
    general_rate = general_rate,
    event_dates = Set{Int16}(Int16(e.date) for e in events)
)

b = Batch(
    n_runs = n_simulations,
    configfile = joinpath(@__DIR__, "config_concert_covid.toml"),
    population = people,
    settingsfile = joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"),
    ind_extension = [:category_ids, :event_ids, :section_ids, :mean_event_contacts, :std_event_contacts, :event_dates, :transmission_prob],
    transmission_function = transmission_func,
    label = "MultiEvent simulation"
)
bd = BatchData(b; rd_style = "EssentialResultData")

event_results = Vector{Any}()
for rd in runs(bd)
    inf_log = infections(rd)
    result = analyze_event_population(inf_log, people, events)
    push!(event_results, result)
end

aggregated = aggregate_event_results(event_results)

run_folder = "Results/run_$(n_simulations)sims_$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM"))"
mkpath(run_folder)

println("\nSimulation complete.")
include("7_Analysis.jl")

if run_validation
    include("8_Validation.jl")
end