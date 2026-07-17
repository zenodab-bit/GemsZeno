import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using GEMS, Parameters, DataFrames, Distributions, CSV,
    CategoricalArrays, JLD2, Random, StatsBase, Plots, StatsPlots, Dates, TOML

# --- Superspreader parameters ---
general_rate = 0.3
std_rate = 0.1
superspreader_prob = 0.10
superspreader_rate = 0.8
superspreader_std = 0.15

include("0_Config.jl")
include("2_Population.jl")
include("3_Contacts.jl")
include("4_Transmission.jl")
include("5_Helpers.jl")

n_simulations = 2
rng = Xoshiro()
run_validation = false




# --- Sample events from categories ---
events = sample_events(event_config, rng)

println("\n=== Sampled Events ===")
for e in events
    println("Event $(e.id) — date: $(e.date), n: $(e.n), contacts: $(e.mean_contacts)")
end

# --- Check event dates against simulation length ---
config = TOML.parsefile(joinpath(@__DIR__, "toml", "config_concert_covid.toml"))
sim_length = config["Simulation"]["StopCriterion"]["parameters"]["limit"]

for e in events
    if e.date > sim_length
        @warn "Event $(e.id) on day $(e.date) is beyond simulation length ($sim_length). Results will be inaccurate."
    end
end

# --- Population setup ---
people, age_groups, sex_levels = prepare_population(event_config, rng)
assign_events!(people, events, event_config, rng)

# --- Build transmission function with event dates ---
transmission_func = SettingRate(
    general_rate=event_config.transmission_rate,
    event_dates=Set{Int16}(Int16(e.date) for e in events)
)

# --- Run batch ---
b = Batch(
    n_runs=n_simulations,
    configfile=joinpath(@__DIR__, "toml", "config_concert_covid.toml"),
    population=people,
    settingsfile=joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"),
    ind_extension=[:category_ids, :event_ids, :section_ids, :mean_event_contacts, :std_event_contacts, :event_dates, :transmission_prob],
    transmission_function=transmission_func,
    label="MultiEvent simulation"
)
bd = BatchData(b; rd_style="EssentialResultData")

# --- Per-event analysis ---
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
include("6_Analysis.jl")

if run_validation
    include("7_Validation.jl")
end