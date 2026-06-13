## === Load Packages and Datasets ===

# Load required Julia packages for simulation, data processing, and visualization
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO,
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

# Load the preprocessed population dataset
people = JLD2.load("Concert_Project/Datastorage/people_Saalekreis.jld2")["data"]

# Load the settings dataset containing configurations for various locations
data_settings = JLD2.load("Concert_Project/Datastorage/settings_Saalekreis.jld2")["data"]




## === Define Age Groups ===

# Function to classify individuals into age groups based on their age
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

ge_groups = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

age_order = [
    "<18", "18-25", "26-30", "31-35", "36-40",
    "41-45", "46-50", "50+"
]

# Apply the age classification to the population dataset
people.age_group = age_group_label.(people.age)


# Convert the age_group column to an ordered categorical variable
people.age_group = categorical(
    people.age_group;
    ordered = true,
    levels = age_order
)




## === Distribute Concert Participants ===

# Function to distribute participants into groups with minimal rounding errors
# This ensures the total number of participants matches the input while preserving percentages
function nice_split(total, groups_percentage_temp)
    # Calculate the raw number of individuals per group
    groups_vector_raw = total * groups_percentage_temp

    # Round up the total to ensure all individuals are accounted for
    total_from_raw = ceil(sum(groups_vector_raw))

    # Floor the raw values to get integer counts per group
    groups_vector = floor.(Int, groups_vector_raw)

    # Calculate the remaining individuals due to flooring
    remainder = total_from_raw - sum(groups_vector)

    # Extract the decimal parts remaining
    decimals = groups_vector_raw .- groups_vector

    # Sort indices by decimal part, from largest to smallest
    idx = sortperm(vec(decimals), rev = true)

    # For each individual remaining (remainder) add them to a group, starting from the group
        # with the highest remainder
    for i in 1:Int(remainder)
        idx_3D = CartesianIndices(decimals)[idx[i]]
        groups_vector[idx_3D] += 1
    end

    # Return the final integer counts for each group
    return groups_vector
end

# Use predefined numbers or percentages for concert groups based on the flag
if concert_groups_number_true
    concert_groups = concert_groups_number
else
    concert_groups = concert_groups_percentage
end

# Initialize a 3D matrix to store the percentage of participants per subgroup
# Dimensions: (concert group, age group, sex group)
groups_percentage = zeros(Float64, length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

# Populate the matrix with the percentage of participants for each subgroup combination
for loc in eachindex(concert_groups)
    for i in eachindex(age_groups_percentage)
        for j in eachindex(sex_groups_percentage)
            # Calculate the percentage for this subgroup
            groups_percentage[loc, i, j] = concert_groups[loc] * age_groups_percentage[i] * sex_groups_percentage[j]
        end
    end
end

# Initialize a 3D matrix to store the integer counts of participants per subgroup
groups_total = zeros(Int, length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

# Assign participants to subgroups using either predefined numbers or percentages
if concert_groups_number_true
    # If using exact numbers, distribute the total proportionally across subgroups
    groups_total = nice_split(1, groups_percentage)
else
    # If using percentages, distribute the total event size across subgroups
    groups_total = nice_split(event_size_total, groups_percentage)
end




## === Assign Participants to Groups ===

# Reset the occupation column to indicate no one is attending by default
people.occupation .= -1

# Function to assign individuals to concert groups based on age, sex, and subgroup counts
function assign_concert!(pop::DataFrame, groups_total, age_order, sex_levels, concert_attendance_levels)
    # Iterate over each concert setting
    for (i, loc) in enumerate(concert_attendance_levels)
        # Iterate over each age group
        for (j, age) in enumerate(age_order)
            # Iterate over each sex group
            for (k, sex) in enumerate(sex_levels)
                # Skip if no participants are assigned to this subgroup
                n = groups_total[i, j, k]
                n == 0 && continue

                # Find eligible candidates: unassigned individuals matching the criteria
                candidates = findall(
                    (pop.age_group .== age) .&
                    (pop.sex .== sex) .&
                    (pop.occupation .== -1)
                )

                # Error if there are not enough candidates to fill the subgroup
                if length(candidates) < n
                    error("Not enough candidates for (age=$age, sex=$sex, concert setting=$loc)")
                end

                # Randomly select the required number of candidates without replacement
                selected = sample(candidates, n; replace = false)

                # Assign the concert setting to the selected individuals
                pop.occupation[selected] .= loc
            end
        end
    end

    # Return the updated population DataFrame
    return pop
end

# Assign people to concert groups based on the calculated subgroup counts
assign_concert!(
    people,
    groups_total,
    age_order,
    sex_levels,
    concert_attendance_levels
)




## === Validate and Analyze Results ===

# Count the number of people in each attendance category
countmap(people.occupation)

# Count the number of people in a specific subgroup
sum((people.age_group .== "31-35") .& (people.sex .== 2) .& (people.occupation .== 1))

# Extract and analyze the sitting subgroup
sitting = people[people.occupation .== 1, :]

# Group sitting participants by age and count the number in each age group
sitting_counts = combine(
    groupby(sitting, :age_group),
    nrow => :count
)

# Convert the age_group column to an ordered categorical for proper sorting
sitting_counts.age_group = categorical(
    sitting_counts.age_group;
    ordered = true,
    levels = age_order
)

# Extract and analyze the standing subgroup
standing = people[people.occupation .== 2, :]

# Group standing participants by age and count the number in each age group
standing_counts = combine(
    groupby(standing, :age_group),
    nrow => :count
)

# Convert the age_group column to an ordered categorical for proper sorting
standing_counts.age_group = categorical(
    standing_counts.age_group;
    ordered = true,
    levels = age_order
)

# Sort both DataFrames by age group for visualization
sort!(sitting_counts, :age_group)
sort!(standing_counts, :age_group)




## === Save Updated Information ===

# Save the updated population data with concert assignments to a new file
data = people
JLD2.@save "Concert_Project/Datastorage/people_Saalekreis_concert.jld2" data

# Reload the saved data to verify it was written correctly
newpeople = JLD2.load("Concert_Project/Datastorage/people_Saalekreis_concert.jld2")["data"]

## END
println("\nEND CUSTOM POPULATION 1")