import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))


using GEMS, Parameters, DataFrames, Dates, Distributions, CSV, 
      CategoricalArrays, JLD2, Random, StatsBase, Plots, StatsPlots

include("0_MultiEvent_Config.jl")
include("2_MultiEvent_Population.jl")
include("3_MultiEvent_Contacts.jl")
include("4_MultiEvent_Transmission.jl")
include("6_MultiEvent_Helpers.jl")

n_simulations = 2
rng = Xoshiro(1234)
run_validation = false

# --- Population setup ---
people, age_groups, sex_levels = prepare_population(event_config)
assign_events!(people, event_config, age_groups, sex_levels, rng)
validate_assignment(people, event_config)

# --- Build event lookup: person_id => (event_id, section_id) ---
event_lookup = Dict{Int32, NamedTuple}()
for row in eachrow(people)
    if row.event_id != -1
        event_lookup[row.id] = (event_id = row.event_id, section_id = row.section_id)
    end
end

# --- Run batch ---
transmission_func = SettingRate(
    general_rate = event_config.transmission_rate,
    event_dates = Set{Int16}(Int16(e.date) for e in event_config.events)
)

b = Batch(
    n_runs = n_simulations,
    configfile = joinpath(@__DIR__, "toml", "config_concert_covid.toml"),
    population = people,
    settingsfile = joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"),
    ind_extension = [:event_id, :section_id, :mean_event_contacts, :event_date],
    transmission_function = transmission_func,
    label = "MultiEvent simulation"
)

bd = BatchData(b; rd_style = "EssentialResultData")

run_folder = "Concert_Project/Results/run_$(n_simulations)sims_$(Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM"))"

# --- Per-event analysis ---
event_results = Vector{Any}()
for rd in runs(bd)
    inf_log = infections(rd)
    result = analyze_event_population(inf_log, event_lookup, event_config, run_validation)
    push!(event_results, result)
end

aggregated = aggregate_event_results(event_results)

println("\nSimulation complete.")