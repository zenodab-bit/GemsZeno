## === Setup ===

#all the packages we will need
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO, 
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

#load the people dataset
people = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/people_Saalekreis.jld2")["data"]

#load the setting dataset
data_settings = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/settings_Saalekreis.jld2")["data"]


## === Concert Attendance ===
no_attendance = -1
seated  = 1
standing  = 2

## === Age groups ===
#the experiment invited only people between 18 and 50 years old
    #the age groups are kept in line with the age groups of the experiment
age_groups = ["<18",
    "18-25", "26-30", "31-35", "36-40", "41-45",
    "46-50", "50+"
]

#function that put people into categories depending on age
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

#here we call the function to group people into age groups
people.age_group = age_group_label.(people.age)

#and we establish the order we want this groups to be in (i.e simple increasing order)
age_order = [
    "<18","18-25","26-30","31-35","36-40",
    "41-45","46-50","50+"
]

#and we change the categories to be of categorical type
people.age_group = categorical(
    people.age_group;
    ordered = true,
    levels = age_order
)

## == Concert splits ===
# Voglio determinare il numero di individui per age group and sex che partecipa al concerto

#we create a function to split nicely people into groups while keeping the exact total number,
    #and respecting as close as possible the ratio between groups
function nice_split(total, groups_percentage)
    #calculate the raw (not necessarily an integer) number of individuals in each group
    groups_vector_raw = total * groups_percentage

    #floor all the values, to get integers
    groups_vector = floor.(Int, groups_vector_raw)

    #calculate how many missing partecipants
    remainder = total - sum(groups_vector)

    #calculate the decimals
    decimals = groups_vector_raw .- groups_vector

    #order them from largest to smallest
    idx = sortperm(decimals, rev= true)

    #starting from the group that was closer to the next integer, add one element
        #repeat for each element missing
    for i in 1:remainder
        groups_vector[idx[i]] += 1
    end

    return groups_vector

end

#we split the population into age groups using the previous function
age_groups = nice_split(event_size_total, age_groups_percentage)

groups_total = zeros(Int, length(age_groups), 2,2)

for i in eachindex(age_groups)

    sex_groups = nice_split(age_groups[i], sex_groups_percentage)

    for j in 1:2

        location_groups = nice_split(sex_groups[j], location_groups_percentage)

        groups_total[i, j, 1] = location_groups[1]
        groups_total[i, j, 2] = location_groups[2]
    end
end



#we create two vectors to keep males and females divided by age 
male_age_groups = Vector{Int}(undef, length(age_groups))
female_age_groups = Vector{Int}(undef, length(age_groups))

#for each age grouo we run the nice_split function again, splitting by gender this time
for i in eachindex(age_groups)
    counts = nice_split(age_groups[i], sex_groups_percentage)
    
    male_age_groups[i] = counts[1]
    female_age_groups[i] = counts[2]
end


seated_male_age_groups = Vector{Int}(undef, length(age_groups))
seated_female_age_groups = Vector{Int}(undef, length(age_groups))
standing_male_age_groups = Vector{Int}(undef, length(age_groups))
standing_female_age_groups = Vector{Int}(undef, length(age_groups))






#--------finding offices with 20 or more people---------------
data_settings = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/settings_Saalekreis.jld2")["data"]
offices = data_settings[:Office] 
offices_bigger20 = offices.id[length.(offices.individuals) .> 20]



#--------end-----------------------





# Reset occupation column
people.occupation .= 0


# === Helper function to assign by age group and sex ===
function assign_role!(pop::DataFrame, age_groups, total, male, female, code)
    for (grp, n_total, n_male, n_female) in zip(age_groups, total, male, female)
        # we put medical workers into the offices larger than 20
        candidates = findall((pop.age_group .== grp) .& (pop.occupation .== 0) .&
        in.(pop.office, Ref(offices_bigger20)))
        male_candidates   = filter(i -> pop.sex[i] == 2, candidates)
        female_candidates = filter(i -> pop.sex[i] == 1, candidates)

        # Safety checks
        if length(male_candidates) < n_male
            error("Not enough male candidates in $grp: have $(length(male_candidates)), need $n_male")
        end
        if length(female_candidates) < n_female
            error("Not enough female candidates in $grp: have $(length(female_candidates)), need $n_female")
        end

        # Sample and assign
        selected_male   = sample(male_candidates, n_male; replace=false)
        selected_female = sample(female_candidates, n_female; replace=false)

        pop.occupation[selected_male]   .= code
        pop.occupation[selected_female] .= code
    end
end

sum((people.age_group .== "35-39") .& (people.sex .== 2) .& (people.occupation .== 0) .& in.(people.office, Ref(offices_bigger20)))

# === Assign all roles ===
assign_role!(people, age_groups, doctor_total, doctor_male, doctor_female, OCC_DOCTOR)
assign_role!(people, age_groups, nurse_total, nurse_male, nurse_female, OCC_NURSE)
assign_role!(people, age_groups, other_total, other_male, other_female, OCC_OTHER)

# === Validation ===
sum(people.occupation .== OCC_DOCTOR)  # 695
sum(people.occupation .== OCC_NURSE)   # 1558
sum(people.occupation .== OCC_OTHER)   # 142

# Age/sex breakdown for doctors
combine(groupby(people[people.occupation .== OCC_DOCTOR, :], [:age_group, :sex]), nrow => :count)
combine(groupby(people[people.occupation .== OCC_NURSE, :], [:age_group, :sex]), nrow => :count)
combine(groupby(people[people.occupation .== OCC_OTHER, :], [:age_group, :sex]), nrow => :count)


# Plot for doctors

doctors = people[people.occupation .== 1001, :]

doctors.age_group = age_group_label.(doctors.age)
doctor_counts = combine(
    groupby(doctors, :age_group),
    nrow => :count
)

nurses = people[people.occupation .== 1002, :]

nurses.age_group = age_group_label.(nurses.age)
nurses_counts = combine(
    groupby(nurses, :age_group),
    nrow => :count
)

other_staff = people[people.occupation .== 1003, :]

other_staff.age_group = age_group_label.(other_staff.age)
other_staff_counts = combine(
    groupby(other_staff, :age_group),
    nrow => :count
)

# age_order = [
#     "<35", "35–39", "40–44", "45–49",
#     "50–54", "55–59", "60–64", "65–69", "70+"
# ]

age_order = [
    "<18","18-24","25-29","30-34","35-39",
    "40-44","45-49","50-54","55-59",
    "60-64","65-69","70+"
]

doctor_counts.age_group = categorical(
    doctor_counts.age_group;
    ordered = true,
    levels = age_order
)

nurses_counts.age_group = categorical(
    nurses_counts.age_group;
    ordered = true,
    levels = age_order
)

other_staff_counts.age_group = categorical(
    other_staff_counts.age_group;
    ordered = true,
    levels = age_order
)


sort!(doctor_counts, :age_group)
sort!(nurses_counts, :age_group)
sort!(other_staff_counts, :age_group)
using StatsPlots

@df doctor_counts bar(
    :age_group,
    :count,
    xlabel = "Age group",
    ylabel = "Number of doctors",
    title = "Number of Doctors by Age Group",
    legend = false,
    bar_width = 0.7
)

@df nurses_counts bar(
    :age_group,
    :count,
    xlabel = "Age group",
    ylabel = "Number of nurses",
    title = "Number of Nurses by Age Group",
    legend = false,
    bar_width = 0.7
)

@df other_staff_counts bar(
    :age_group,
    :count,
    xlabel = "Age group",
    ylabel = "Number of other med staff",
    title = "Number of other medical staff by Age Group",
    legend = false,
    bar_width = 0.7
)

# -length dismatch
bar(
    doctor_counts.age_group,
    [doctor_counts.count nurses_counts.count other_staff_counts.count],
    xlabel = "Age group",
    ylabel = "Number of workers",
    title = "Number of medical staff by Age Group",
    legend = false,
    bar_width = 0.3
)

vscodedisplay(people)


#----------------------------------------
# saving updated information

data = people
JLD2.@save "localdata/people_Saalekreis_base.jld2" data
newpeople = JLD2.load("localdata/people_Saalekreis_base.jld2")["data"]

subset(newpeople,:occupation => ByRow(x -> x > 1000), skipmissing=true) |>vscodedisplay
############------------------###########################

vscodedisplay(offices)