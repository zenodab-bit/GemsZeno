## === Simple Simulation ===
sim = Simulation()
run!(sim)
rd = ResultData(sim)

## === Base Simulation ===
sim_base = Simulation(
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Base simulation")
run!(sim_base)
rd_base = ResultData(sim_base)

## === Simulation Saalekreis Hospital ===
sim_Saalekreis_Hospital = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/influenza_hh_012_copy.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_example.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Hospital simulation")
run!(sim_Saalekreis_Hospital)
rd_Saalekreis_Hospital = ResultData(sim_Saalekreis_Hospital)

## == Plot ==
gemsplot([rd_base, rd_Saalekreis_Hospital])
## === Simulation Saalekreis Concert ===

sim_base = Simulation(population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2", 
settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
label = "Concert simulation")
run!(sim_base)
rd_base = ResultData(sim_base)