## === Load Packages and Datasets ===

# Load required Julia packages for simulation, data processing, and visualization
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO,
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

# Load the preprocessed population dataset
people = JLD2.load(joinpath(@__DIR__, "Datastorage", "people_Saalekreis.jld2"))["data"]

# Load the settings dataset containing configurations for various locations
data_settings = JLD2.load(joinpath(@__DIR__, "Datastorage", "settings_Saalekreis.jld2"))["data"]




## === Define Age Groups ===

# Function to classify individuals into age groups based on their age
function age_group_label(age, age_boundaries)
    for i in eachindex(age_boundaries)
        if age <= age_boundaries[i]
            return "<=$(age_boundaries[i])"
        end
    end
    return ">$(age_boundaries[end])"
end

# We take the age boundaries and convert them into labels for age groups
age_groups = [i == length(age_boundaries) + 1 ? ">$(age_boundaries[end])" : "<=$(age_boundaries[i])" for i in 1:length(age_boundaries)+1]

# Apply the age classification to the population dataset
people.age_group = age_group_label.(people.age, Ref(age_boundaries))


# Convert the age_group column to an ordered categorical variable
people.age_group = categorical(
    people.age_group;
    ordered = true,
    levels = age_groups
)




## === Distribute Concert Participants ===

# Function to distribute participants into groups with minimal rounding errors, especially important the more subgroups you have
# This ensures the total number of participants matches the input (we end up with exactly the total number we declared at the beginning)
    # while preserving percentages as close as possible
function nice_split(total, groups_percentage_temp)
    # Calculate the raw number of individuals per group
    groups_vector_raw = total * groups_percentage_temp

    # Round up the total to ensure all individuals are accounted for
    total_from_raw = ceil(sum(groups_vector_raw))

    # Floor the raw values to get the integer counts per group (this is the number of individuals that are assigned for sure to each group)
    groups_vector = floor.(Int, groups_vector_raw)

    # Calculate the remaining individuals due to flooring (how many individuals have not being assigned fully to a group)
    remainder = total_from_raw - sum(groups_vector)

    # Extract the decimal parts remaining
    decimals = groups_vector_raw .- groups_vector

    # Sort indices by decimal part, from largest to smallest
    idx = sortperm(vec(decimals), rev = true)

    # For each individual not assigned (remainder) add them to a group, starting from the group
        # with the highest remainder
    for i in 1:Int(remainder)
        idx_3D = CartesianIndices(decimals)[idx[i]]
        groups_vector[idx_3D] += 1
    end

    # Return the final integer counts for each group
    return groups_vector
end

# as we have the possibility of declaring exact numbers of sitting/standing OR the percentage of sitting/standing
    # we need to have the right groups
# if we are giving the exact numbers for the two locations, use them
if concert_groups_number_true
    # use the numbers as concert groups
    concert_groups = concert_groups_number
# else if we are giving the percentages, ignore the numbers and use the percentages
else
    concert_groups = concert_groups_percentage
end

# Initialize a 3D matrix to store the percentage of participants per subgroup
# Dimensions: (concert group, age group, 2 (sexs))
# Populate the matrix with the percentage of participants for each subgroup combination
groups_percentage = zeros(Float64, length(concert_groups), length(age_groups_percentage), 2)

# for each concert_groups (event)
for loc in eachindex(concert_groups)
    # and for each age group
    for age in eachindex(age_groups_percentage)
        # calculate the percentage of males that are in that concert groups, and age group
        groups_percentage[loc, age, 1] = concert_groups[loc] * age_groups_percentage[age] * sex_groups_percentage[age][1]
        # calculate the percentage of females that are in that concert groups, and age group
        groups_percentage[loc, age, 2] = concert_groups[loc] * age_groups_percentage[age] * sex_groups_percentage[age][2]
    end
end    


# Initialize a 3D matrix to store the integer counts of participants per subgroup
groups_total = zeros(Int, length(concert_groups), length(age_groups_percentage), 2)

# Assign participants to subgroups using either predefined numbers or percentages
    # if we gave the exact numbers for each event, when we call the nice_split function the names are a misnomer.
    # When we calculate the groups_percentages, as they get multiplied by concert_groups (that in this case are a number) we get
    # a number of individuals (not integer) instead of a percentage.
    # As such we pass as total 1, otherwise we would have population * population
if concert_groups_number_true
    # If using exact numbers, distribute the total proportionally across subgroups
    groups_total = nice_split(1, groups_percentage)
else
    # in case of percentage this is easier. groups_percentages are proper percentages and so we can
        # easily split the event_size_total using the percentages
    groups_total = nice_split(event_size_total, groups_percentage)
end




## === Assign Participants to Groups ===

# Reset the occupation column to indicate no one is attending by default
people.occupation .= -1

# Function to assign individuals to concert groups based on age, sex, and subgroup counts
function assign_concert!(pop::DataFrame, groups_total, age_groups, sex_levels, concert_attendance_levels)
    # Iterate over each concert setting
    for (i, loc) in enumerate(concert_attendance_levels)
        # Iterate over each age group
        for (j, age) in enumerate(age_groups)
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
    age_groups,
    sex_levels,
    concert_attendance_levels
)




## === Validate and Analyze Results ===
# This section does not truly run when a simulation is called
    # it contains a series of tests and data that can be used to check that the previous code in this file is splitting the population as expected


# Count the number of people in each attendance category
countmap(people.occupation)

# Count the number of people in a specific subgroup (age group * sex * occupation)
sum((people.age_group .== ">65") .& (people.sex .== 2) .& (people.occupation .== 1))

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
    levels = age_groups
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
    levels = age_groups
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