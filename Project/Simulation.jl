## === Simulation Concert ===
sim_concert = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/config_concert.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Concert simulation")
run!(sim_concert)
rd_concert = ResultData(sim_concert)

## === Simulation 