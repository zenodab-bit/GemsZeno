## === Global Configuration ===

# Concert Settings (not used in base simulation)
const concert_date = 15
const event_size_total = 0
const concert_groups_percentage = [0.5, 0.5]
const concert_groups_number = [0, 0]
const concert_attendance_levels = [1, 2]  # -1: Not participating, 1: Sitting, 2: Standing
const concert_groups_number_true = false

# Demographic Settings
const sex_groups_percentage = [0.5, 0.5]
const sex_levels = [1, 2]  # 1: Male, 2: Female
# Customizable age group distribution (must sum to 1.0)
const age_groups_percentage = [0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125]
const age_groups = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]







## === Include Custom Modules ===

include("1.1_Custom_Population.jl")







## === Run Base Simulation ===

sim_base = Simulation(
    configfile = "Concert Project/toml/config_base.toml",
    population = "Concert Project/Datastorage/people_Saalekreis.jld2",
    settingsfile = "Concert Project/Datastorage/settings_Saalekreis.jld2",
    label = "Base simulation"
)
run!(sim_base)
rd_base = ResultData(sim_base)







## === Plots ===

# Plot 1: Total cases across all settings
gp = gemsplot(rd_base)
png(gp, "Concert Project/Plots/Single_general_base.png")

# Plot 2: Cases by setting (Household, School, Workplace, GlobalSetting)
tick_cases_base = rd_base.data["dataframes"]["tick_cases_per_setting"]
filtered_tick_cases = filter(row -> row.setting_type in ['h', 's', 'w', 'g'], tick_cases_base)
rd_base.data["dataframes"]["tick_cases_per_setting"] = filtered_tick_cases
gp1 = gemsplot(rd_base, type = :TickCasesBySetting)
png(gp1, "Concert Project/Plots/Single_cases_base.png")







## === Results ===

# Total infected in all settings
inds_base = individuals(sim_base)
println("Total infected in Base Simulation: ", sum(infected.(inds_base)))

# Total infected in GlobalSetting
global_cases_base = filter(row -> row.setting_type == 'g', rd_base.data["dataframes"]["tick_cases_per_setting"])
total_global_infected_base = sum(global_cases_base.daily_cases)
println("Total infected in GlobalSetting (Base Simulation): ", total_global_infected_base)

## END
println("END SIMULATION 4.0 BASE SIMULATION")