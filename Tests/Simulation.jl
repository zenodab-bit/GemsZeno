## === Simulation Concert ===
sim_concert = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/config_concert.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Concert simulation")
run!(sim_concert)
rd_concert = ResultData(sim_concert)

## === Simulation Concert 2 === 
sim_concert2 = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/config_concert2.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Concert 2 simulation")
run!(sim_concert2)
rd_concert2 = ResultData(sim_concert2)

## === Plot ===
gp = gemsplot([rd_concert, rd_concert2])
png(gp, "/home/bernaze/GemsZeno/Project/Plots/plot_1.png")

##

inds1 = individuals(sim_concert)
inds2 = individuals(sim_concert2)

sum(infected.(inds1))
sum(infected.(inds2))