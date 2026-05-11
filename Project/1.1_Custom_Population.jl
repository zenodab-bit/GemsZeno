## === Load all the packages and datasets ===

# Load all required packages for the simulation and data processing
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO,
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

# Load the population dataset for Saalekreis
people = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis.jld2")["data"]

# Load the settings dataset for Saalekreis
data_settings = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2")["data"]

## === Setup and configure all the Parameters ===

# Specify the total number of participants at the concert event
event_size_total = 10000
#1159

# Specify the percentage of sitting / standing people at the concert
concert_groups_percentage = [0.6, 0.4]

# Alternatively, specify the exact number of people sitting/standing
concert_groups_number = [583, 576]

# Code for type of attendance:
# -1: Not participating
# 1: Sitting
# 2: Standing
concert_attendance_levels = [1, 2]

# Flag to indicate whether to use exact numbers or percentages for concert groups
concert_groups_number_true = true

# Specify the sex group division as a percentage (male / female)
sex_groups_percentage = [0.366, 0.634]

# Sex levels:
# 1: Male
# 2: Female
sex_levels = [1, 2]

# Specify the age group division as a percentage
age_groups_percentage = [
    0.000,
    0.293,
    0.139,
    0.205,
    0.153,
    0.118,
    0.092,
    0.000
]

## === Set the age groups ===

# The experiment invited only people between 18 and 50 years old
# The age groups are aligned with the experiment's age groups
age_groups = ["<18",
    "18-25", "26-30", "31-35", "36-40", "41-45",
    "46-50", "50+"]

# Function to categorize individuals into age groups based on their age
function age_group_label(age)
    if age < 18
        "<18"
    elseif age <= 24
        "18-25"
    elseif age <= 29
        "26-30"
    elseif age <= 34
        "31-35"
    elseif age <= 39
        "36-40"
    elseif age <= 44
        "41-45"
    elseif age <= 49
        "46-50"
    else
        "50+"
    end
end

# Apply the age_group_label function to categorize people into age groups
people.age_group = age_group_label.(people.age)

# Define the order for age groups (increasing order)
age_order = [
    "<18", "18-25", "26-30", "31-35", "36-40",
    "41-45", "46-50", "50+"
]

# Convert the age_group column to a categorical type with the specified order
people.age_group = categorical(
    people.age_group;
    ordered = true,
    levels = age_order
)

## == Concert splits ==

# Function to split participants into groups (e.g., sitting/standing) while minimizing rounding errors
# This ensures integer counts for each group while preserving the original percentages as closely as possible
function nice_split(total, groups_percentage_temp)
    # Calculate the raw (non-integer) number of individuals in each group
    groups_vector_raw = total * groups_percentage_temp

    # Calculate the ceiling of the total to ensure all individuals are accounted for
    total_from_raw = ceil(sum(groups_vector_raw))

    # Floor all values to get integer counts
    groups_vector = floor.(Int, groups_vector_raw)

    # Calculate how many individuals remain unassigned due to flooring
    remainder = total_from_raw - sum(groups_vector)

    # Calculate the decimal parts of the raw values to determine where to add the remainder
    decimals = groups_vector_raw .- groups_vector

    # Order the decimal parts from largest to smallest to prioritize adding to the closest groups
    idx = sortperm(vec(decimals), rev = true)

    # Add one individual to the groups with the largest decimal parts until all are assigned
    for i in 1:Int(remainder)
        idx_3D = CartesianIndices(decimals)[idx[i]]
        groups_vector[idx_3D] += 1
    end

    # Return the vector containing the number of individuals in each group
    return groups_vector
end

# Determine whether to use predefined numbers or percentages for concert groups
if concert_groups_number_true == true
    concert_groups = concert_groups_number
else
    concert_groups = concert_groups_percentage
end

# Initialize a matrix to store the percentage of participants in each subgroup (sitting/standing, age, sex)
groups_percentage = zeros(Float64, length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

# Calculate the percentage of participants for each combination of concert setting, age group, and sex
for loc in eachindex(concert_groups)
    for i in eachindex(age_groups_percentage)
        for j in eachindex(sex_groups_percentage)
            # Calculate the percentage for this specific subgroup
            groups_percentage[loc, i, j] = concert_groups[loc] * age_groups_percentage[i] * sex_groups_percentage[j]
        end
    end
end

# Initialize a matrix to store the total number of participants in each subgroup
groups_total = zeros(Int, length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

# Assign participants to subgroups based on numbers or percentages
if concert_groups_number_true == true
    # If using predefined numbers, convert percentages to integers
    groups_total = nice_split(1, groups_percentage)
else
    # If using percentages, calculate the number of participants for each subgroup
    groups_total = nice_split(event_size_total, groups_percentage)
end

## === Assign people to each group ===

# Reset the occupation column to -1 (not attending the concert)
people.occupation .= -1

# Function to assign individuals to concert groups (sitting/standing) based on age and sex
function assign_concert!(pop::DataFrame, groups_total, age_order, sex_levels, concert_attendance_levels)

    # Iterate over each concert setting (e.g., sitting, standing)
    for (i, loc) in enumerate(concert_attendance_levels)
        # Iterate over each age group
        for (j, age) in enumerate(age_order)
            # Iterate over each sex group
            for (k, sex) in enumerate(sex_levels)

                # Skip if the subgroup has zero participants
                n = groups_total[i, j, k]
                n == 0 && continue

                # Find eligible candidates: individuals in the current age and sex group who are not yet assigned
                candidates = findall(
                    (pop.age_group .== age) .&
                    (pop.sex .== sex) .&
                    (pop.occupation .== -1)
                )

                # Check if there are enough candidates
                if length(candidates) < n
                    error("Not enough candidates for (age=$age, sex=$sex, concert setting=$loc)")
                end

                # Randomly select the required number of candidates without replacement
                selected = sample(candidates, n; replace = false)

                # Assign the concert setting (sitting/standing) to the selected individuals
                pop.occupation[selected] .= loc
            end
        end
    end

    # Return the updated DataFrame
    return pop
end

# Assign people to concert groups (sitting/standing) based on the calculated subgroups
assign_concert!(
    people,
    groups_total,
    age_order,
    sex_levels,
    concert_attendance_levels
)

## === Run some validation tests and plots ===

# Count the number of people in each attendance category (-1: not attending, 1: sitting, 2: standing)
countmap(people.occupation)

# Count the number of people in a specific subgroup (e.g., age 31-35, female, sitting)
sum((people.age_group .== "31-35") .& (people.sex .== 2) .& (people.occupation .== 1))

# Store all people assigned to sitting
sitting = people[people.occupation .== 1, :]

# Group sitting people by age and count the number in each age group
sitting_counts = combine(
    groupby(sitting, :age_group),
    nrow => :count
)

# Convert the age_group column to a categorical type with the specified order
sitting_counts.age_group = categorical(
    sitting_counts.age_group;
    ordered = true,
    levels = age_order
)

# Store all people assigned to standing
standing = people[people.occupation .== 2, :]

# Group standing people by age and count the number in each age group
standing_counts = combine(
    groupby(standing, :age_group),
    nrow => :count
)

# Convert the age_group column to a categorical type with the specified order
standing_counts.age_group = categorical(
    standing_counts.age_group;
    ordered = true,
    levels = age_order
)

# Sort the DataFrames by age group for plotting
sort!(sitting_counts, :age_group)
sort!(standing_counts, :age_group)

using StatsPlots

# @df sitting_counts bar(
#     :age_group,
#     :count,
#     xlabel = "Age group",
#     ylabel = "Number of sitting",
#     title = "Number of sitting people by Age Group",
#     legend = false,
#     bar_width = 0.7
# )

# @df standing_counts bar(
#     :age_group,
#     :count,
#     xlabel = "Age group",
#     ylabel = "Number of standing",
#     title = "Number of standing people by Age Group",
#     legend = false,
#     bar_width = 0.7
# )

## === Saving updated information ===

# Save the updated population data with concert assignments
data = people
JLD2.@save "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2" data
newpeople = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2")["data"]

## End of script
print("END CUSTOM POPULATION")