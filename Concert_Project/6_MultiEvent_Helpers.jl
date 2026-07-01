include("0_MultiEvent_Config.jl")
include("2_MultiEvent_Population.jl")
include("3_MultiEvent_Contacts.jl")
include("4_MultiEvent_Transmission.jl")
include("5_MultiEvent_Logger_ResultData.jl")
include("6_MultiEvent_Helpers.jl")

n_simulations = 10
rng = Xoshiro(1234)

people, age_groups, sex_levels = prepare_population(event_config)
assign_events!(people, event_config, age_groups, sex_levels, rng)
validate_assignment(people, event_config)

for i in 1:n_simulations
    sim = Simulation(
        configfile = "Concert_Project/toml/config_concert_covid.toml",
        population = people,
        settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
        ind_extension = [:event_id, :section_id, :mean_event_contacts, :event_date],
        label = "MultiEvent simulation run $i"
    )
    run!(sim)
end