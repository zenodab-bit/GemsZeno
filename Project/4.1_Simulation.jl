## === Simulation: Concert 1 ===
# Initialize and run the first concert simulation with custom contact sampling
sim_concert = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/config_concert.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    global_setting_contacts = ConcertContacts(),  # Use custom contact sampling for GlobalSetting
    label = "Concert simulation"
)
run!(sim_concert)

# Store the results of the first simulation
rd_concert = ResultData(sim_concert)


## === Simulation: Concert 2 ===
# Initialize and run the second concert simulation with default settings
sim_concert2 = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/config_concert2.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Concert 2 simulation"
)
run!(sim_concert2)

# Store the results of the second simulation
rd_concert2 = ResultData(sim_concert2)

## === Plot: All Settings ===
# Plot the total cases for both simulations
gp = gemsplot([rd_concert, rd_concert2])
png(gp, "/home/bernaze/GemsZeno/Project/Plots/plot_general_1vs0_30day.png")

# Extract the tick_cases_per_setting DataFrames for both simulations
tick_cases_concert = rd_concert.data["dataframes"]["tick_cases_per_setting"]
tick_cases_concert2 = rd_concert2.data["dataframes"]["tick_cases_per_setting"]

## === Plot: Filtered Settings ===
# Filter to include only Household (h), School (s), Workplace (w), and GlobalSetting (g)
rd_concert.data["dataframes"]["tick_cases_per_setting"] = filter(row -> row.setting_type in ['h', 's', 'w', 'g'], tick_cases_concert)
rd_concert2.data["dataframes"]["tick_cases_per_setting"] = filter(row -> row.setting_type in ['h', 's', 'w', 'g'], tick_cases_concert2)

# Plot the filtered results for both simulations
gp1 = gemsplot([rd_concert, rd_concert2], type = :TickCasesBySetting)
png(gp1, "/home/bernaze/GemsZeno/Project/Plots/plot_Setting_1vs0_30day.png")

## === Total Infected Individuals ===
# Extract all individuals from both simulations
inds1 = individuals(sim_concert)
inds2 = individuals(sim_concert2)

# Count the total number of infected individuals in each simulation
println("Total infected in Concert 1: ", sum(infected.(inds1)))
println("Total infected in Concert 2: ", sum(infected.(inds2)))

## === Total Infected in GlobalSetting ===
# Sum the daily cases for GlobalSetting ('g') in Concert 1
global_cases = filter(row -> row.setting_type == 'g', rd_concert.data["dataframes"]["tick_cases_per_setting"])
total_global_infected = sum(global_cases.daily_cases)
println("Total infected in GlobalSetting (Concert 1): ", total_global_infected)

# Sum the daily cases for GlobalSetting ('g') in Concert 2
global_cases2 = filter(row -> row.setting_type == 'g', rd_concert2.data["dataframes"]["tick_cases_per_setting"])
total_global_infected2 = sum(global_cases2.daily_cases)
println("Total infected in GlobalSetting (Concert 2): ", total_global_infected2)

total_global_infected 
total_global_infected2