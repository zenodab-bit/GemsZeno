## === Global Configuration ===

# --- Concert Settings ---
# Simulation tick when the concert event would occur
const concert_date = 15

# Total number of participants at the concert event
const event_size_total = 4166

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
const mean_number_of_contacts_sitting = 5

# Average number of contacts for standing participants
const mean_number_of_contacts_standing = 0


n_simulations = 1

## === Include Custom Modules ===

# Include custom population, contact, and transmission modules
include("1.1_Custom_Population.jl")
include("2.1_Custom_Contacts.jl")
include("3.1_Custom_Transmission.jl")





## === Run Multiple Base Simulations ===
# Initialize and run simulations
sims = Simulation[]
for i in 1:n_simulations
    sim = Simulation(
        configfile = "Concert Project/toml/config_concert.toml",
        population = "Concert Project/Datastorage/people_Saalekreis.jld2",
        settingsfile = "Concert Project/Datastorage/settings_Saalekreis.jld2",
        global_setting_contacts = ConcertContacts(),
        label = "Base simulation"
    )
    push!(sims, sim)
end

# Create and run a batch of simulations
b = Batch(sims...)
run!(b)

# Get ResultData once for each simulation and store it
sim_results = Dict{Int, Any}()
for (i, sim) in enumerate(sims)
    sim_results[i] = ResultData(sim)
end

# Get combined results for batch plotting
rd = ResultData(b)

## === Plot: Total Cases ===
gp_total = gemsplot(rd)
png(gp_total, "Concert Project/Plots/Batch_general_first.png")

## === Plot: Averaged Cases by Setting ===
# Collect all tick_cases_per_setting DataFrames
all_tick_cases = DataFrame[]
for i in 1:length(sims)
    df = sim_results[i].data["dataframes"]["tick_cases_per_setting"]
    push!(all_tick_cases, df)
end

# Combine and filter
combined_df = vcat(all_tick_cases...)
filtered_df = filter(row -> row.setting_type in ['h', 's', 'w', 'g'], combined_df)

# Calculate mean daily cases
avg_df = combine(
    groupby(filtered_df, [:tick, :setting_type]),
    :daily_cases => mean => :avg_daily_cases
)

# Create plot
setting_types = unique(avg_df.setting_type)
p = plot(
    title = "Average Infections per Setting (All Simulations)",
    xlabel = "Time Step",
    ylabel = "Average Daily Cases",
    legend = :topright,
    size = (800, 600)
)

for setting in setting_types
    setting_data = filter(row -> row.setting_type == setting, avg_df)
    plot!(
        p,
        setting_data.tick,
        setting_data.avg_daily_cases,
        label = string(setting),
        linewidth = 2
    )
end
png(p, "Concert Project/Plots/Batch_cases_first.png")

## === Results Collection ===
# Initialize dictionaries to store results
global_infected_values = Float64[]
day_infected_values = Dict{Int, Vector{Float64}}()
for day in [5, 15, 25]
    day_infected_values[day] = Float64[]
end

for i in 1:length(sims)
    # GlobalSetting total
    global_cases = filter(row -> row.setting_type == 'g', sim_results[i].data["dataframes"]["tick_cases_per_setting"])
    push!(global_infected_values, sum(global_cases.daily_cases))

    # Specific days - get daily cases AT the exact day, not cumulative
    cases_df = sim_results[i].data["dataframes"]["tick_cases_per_setting"]
    for day in [5, 15, 25]
        # Filter for the exact day (not <= day)
        exact_day = filter(row -> row.tick == day, cases_df)
        # Sum daily cases for that exact day
        push!(day_infected_values[day], sum(exact_day.daily_cases))
    end
end

## === Print All Results ===
# Print GlobalSetting results
println("\n=== GlobalSetting Results ===")
for (i, val) in enumerate(global_infected_values)
    println("Simulation $i - Total infected in GlobalSetting: ", val)
end
println("Average total infected in GlobalSetting: ", mean(global_infected_values))

# Print specific days results
println("\n=== New Infections at Specific Days ===")
for day in [5, 15, 25]
    println("\nDay $day:")
    for (i, val) in enumerate(day_infected_values[day])
        println("  Simulation $i: ", val)
    end
    println("  Average: ", mean(day_infected_values[day]))
end







## END

println("END SIMULATION 4.3 BATCHES")