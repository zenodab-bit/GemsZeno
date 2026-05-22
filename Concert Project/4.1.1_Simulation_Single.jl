## === Global Configuration ===

# --- Concert Settings ---
# Simulation tick when the concert event would occur
const concert_date = 15

# Total number of participants at the concert event
const event_size_total = 1000

# Percentage of participants in sitting and standing sections
const concert_groups_percentage = [1, 0]

# Exact number of participants in sitting and standing sections
const concert_groups_number = [0, 0]

# Occupation codes for concert attendance
# -1: Not participating, 1: Sitting, 2: Standing
const concert_attendance_levels = [1, 2]

# Flag to use exact numbers or percentages for concert groups
const concert_groups_number_true = false

# --- Demographic Settings ---
# Percentage of male and female participants
const sex_groups_percentage = [0.5, 0.5]

# Sex codes: 1: Male, 2: Female
const sex_levels = [1, 2]

# Equal percentage distribution of participants across all age groups
const age_groups_percentage = [
    0.125,  # Under 18
    0.125,  # 18-25
    0.125,  # 26-30
    0.125,  # 31-35
    0.125,  # 36-40
    0.125,  # 41-45
    0.125,  # 46-50
    0.125   # 50 and over
]

# Age group labels
const age_groups = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

# --- Contact Settings ---
# Average number of contacts for sitting participants
const mean_number_of_contacts_sitting = 1

# Average number of contacts for standing participants
const mean_number_of_contacts_standing = 0





## === Include Custom Modules ===

include("1.1_Custom_Population.jl")
include("2.1.1_Custom_Contacts.jl")
include("3.1_Custom_Transmission.jl")







## === Run Simulation ===

sim_concert = Simulation(
    configfile = "Concert Project/toml/config_concert.toml",
    population = "Concert Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "Concert Project/Datastorage/settings_Saalekreis.jld2",
    global_setting_contacts = ConcertContacts(),
    label = "Concert simulation"
)
run!(sim_concert)
rd_concert = ResultData(sim_concert)







## === Plots ===

# Plot 1: Total cases across all settings
gp = gemsplot(rd_concert)
png(gp, "Concert Project/Plots/General_validation_1.png")

# Plot 2: Cases by setting (Household, School, Workplace, GlobalSetting)
tick_cases_concert = rd_concert.data["dataframes"]["tick_cases_per_setting"]
filtered_tick_cases = filter(row -> row.setting_type in ['h', 's', 'w', 'g'], tick_cases_concert)
rd_concert.data["dataframes"]["tick_cases_per_setting"] = filtered_tick_cases
gp1 = gemsplot(rd_concert, type = :TickCasesBySetting)
png(gp1, "Concert Project/Plots/Cases_by_setting_validation_1.png")

# Plot 3: Actively infectious over time
using Plots
max_day = 30
infectious_counts = [count(ind -> GEMS.is_infectious(ind, Int16(day)), individuals(sim_concert)) for day in 1:max_day]
p_infectious = plot(
    1:max_day,
    infectious_counts,
    title = "Actively Infectious Individuals Over Time",
    xlabel = "Day",
    ylabel = "Number of Infectious Individuals",
    label = "All Settings",
    linewidth = 2,
    size = (800, 600)
)
png(p_infectious, "Concert Project/Plots/infectious_people_validation_1.png")







## === Results ===

# Total infected in all settings
inds = individuals(sim_concert)
println("Total infected in the simulation: ", sum(infected.(inds)))

# Total infected in GlobalSetting (ConcertSetting)
global_cases = filter(row -> row.setting_type == 'g', rd_concert.data["dataframes"]["tick_cases_per_setting"])
total_global_infected = sum(global_cases.daily_cases)
println("Total infected in GlobalSetting (Concert): ", total_global_infected)

# Actively infectious on specific days
println("\n=== Actively Infectious People on Specific Days (All Settings) ===")
for day in [15]
    infectious_count = count(ind -> GEMS.is_infectious(ind, Int16(day)), inds)
    println("On day $day: $infectious_count actively infectious people in ALL settings")
end

## END
println("END SIMULATION 4.1.1 SINGLE SIMULATION")

