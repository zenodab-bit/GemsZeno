## === Global Configuration ===

# --- Concert Settings ---
# Simulation tick when the concert event would occur (not used in base simulation)
const concert_date = 15

# Total number of participants at the concert event (none in base simulation)
const event_size_total = 1000

# Percentage of participants in sitting and standing sections (not used)
const concert_groups_percentage = [0.5, 0.5]

# Exact number of participants in sitting and standing sections (none in base simulation)
const concert_groups_number = [0, 0]

# Occupation codes for concert attendance (not used in base simulation)
# -1: Not participating, 1: Sitting, 2: Standing
const concert_attendance_levels = [1, 2]

# Flag to use exact numbers or percentages for concert groups (not used)
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
# Average number of contacts for sitting participants (not used in base simulation)
const mean_number_of_contacts_sitting = 5

# Average number of contacts for standing participants (not used in base simulation)
const mean_number_of_contacts_standing = 0




## === Include Custom Modules ===

# Include custom population, contact, and transmission modules
include("1.1_Custom_Population.jl")
include("2.1_Custom_Contacts.jl")
include("3.1_Custom_Transmission.jl")




## === Run Simulation ===

# Initialize and run the concert simulation
sim_concert = Simulation(
    configfile = "Concert Project/toml/config_concert.toml",
    population = "Concert Project/Datastorage/people_Saalekreis_concert.jld2",
    settingsfile = "Concert Project/Datastorage/settings_Saalekreis.jld2",
    global_setting_contacts = ConcertContacts(),
    label = "Concert simulation"
)
run!(sim_concert)

# Store the results of the simulation
rd_concert = ResultData(sim_concert)




## === Plot: All Settings ===

# Generate a plot of total cases across all settings
gp = gemsplot(rd_concert)
png(gp, "Concert Project/Plots/General_validation_1.png")

# Extract the tick_cases_per_setting DataFrame
tick_cases_concert = rd_concert.data["dataframes"]["tick_cases_per_setting"]




## === Plot: Filtered Settings ===

# Filter to include only Household, School, Workplace, and GlobalSetting
rd_concert.data["dataframes"]["tick_cases_per_setting"] =
    filter(row -> row.setting_type in ['h', 's', 'w', 'g'], tick_cases_concert)

# Generate a plot of cases by setting
gp1 = gemsplot(rd_concert, type = :TickCasesBySetting)
png(gp1, "Concert Project/Plots/Cases_by_setting_validation_1.png")




## === Total Infected Individuals ===

# Extract all individuals from the simulation
inds = individuals(sim_concert)

# Count and print the total number of infected individuals
println("Total infected in Concert: ", sum(infected.(inds)))




## === Total Infected in GlobalSetting ===

# Sum the daily cases for GlobalSetting (concert)
global_cases = filter(row -> row.setting_type == 'g', rd_concert.data["dataframes"]["tick_cases_per_setting"])
total_global_infected = sum(global_cases.daily_cases)
println("Total infected in GlobalSetting (Concert): ", total_global_infected)

# Return the total infected in GlobalSetting
total_global_infected