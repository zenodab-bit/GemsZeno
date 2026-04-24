##
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO, Distributions, CSV, CategoricalArrays, JLD2, Random
BASE_FOLDER = dirname(dirname(pathof(GEMS)))

# individuals analysis
people = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis.jld2")["data"]


using DataFrames, StatsBase, Random

# === Occupation codes ===
OCC_DOCTOR = 1001
OCC_NURSE  = 1002
OCC_OTHER  = 1003

# === Age groups ===
#age_groups = ["<35","35–39","40–44","45–49","50–54","55–59","60–64","65–69","70+"]
age_groups = ["<18",
    "18-24", "25-29", "30-34", "35-39", "40-44",
    "45-49", "50-54", "55-59", "60-64", "65-69", "70+"
]


function age_group_label(age)
    if age < 18 
        "<18"
    elseif age <= 24
        "18-24"
    elseif age <= 29
        "25-29"
    elseif age <= 34
        "30-34"
    elseif age <= 39
        "35-39"
    elseif age <= 44
        "40-44"
    elseif age <= 49
        "45-49"
    elseif age <= 54
        "50-54"
    elseif age <= 59
        "55-59"
    elseif age <= 64
        "60-64"
    elseif age <= 69
        "65-69"
    else
        "70+"
    end
end


people.age_group = age_group_label.(people.age)

age_order = [
    "<18","18-24","25-29","30-34","35-39",
    "40-44","45-49","50-54","55-59",
    "60-64","65-69","70+"
]


people.age_group = categorical(
    people.age_group;
    ordered = true,
    levels = age_order
)

# === Doctors: total counts & male/female splits ===
# doctor_total  = [124, 28, 42, 70, 97, 125, 97, 70, 42]  # sum = 695
# doctor_male   = [65, 17, 21, 39, 48, 76, 55, 39, 23]
# doctor_female = [59, 11, 21, 31, 49, 49, 42, 31, 19]
doctor_total = [
    0,    # <18
    0,    # 18–24
    43,   # 25–29
    65,   # 30–34
    24,   # 35–39
    38,   # 40–44
    64,   # 45–49
    88,   # 50–54
    108,  # 55–59
    88,   # 60–64
    58,   # 65–69
    38    # 70+
]

doctor_male = [
    0,    # <18
    0,    # 18–24
    18,   # 25–29
    26,   # 30–34
    10,   # 35–39
    15,   # 40–44
    29,   # 45–49
    41,   # 50–54
    58,   # 55–59
    54,   # 60–64
    38,   # 65–69
    20    # 70+
]
doctor_female = doctor_total .- doctor_male

sum(doctor_total)

# === Nurses: example numbers, adjust to your data ===
# nurse_total  = [200, 100, 150, 200, 250, 300, 200, 100, 58]  # sum = 1558
# nurse_male   = [50, 20, 30, 40, 50, 60, 40, 20, 8]
# nurse_female = [150, 80, 120, 160, 200, 240, 160, 80, 50]
nurse_total = [
    0,    # <18
    86,   # 18–24
    100,  # 25–29
    99,   # 30–34
    140,  # 35–39
    180,  # 40–44
    215,  # 45–49
    225,  # 50–54
    165,  # 55–59
    30,   # 60–64
    5,    # 65–69
    0     # 70+
]
nurse_female = round.(Int, nurse_total .* 0.80)
nurse_male   = nurse_total .- nurse_female

sum(nurse_total)

# === Other medical staff ===
# other_total  = [20, 10, 15, 20, 25, 25, 15, 7, 5]  # sum = 142
# other_male   = [10,5,8,10,12,13,8,4,2]
# other_female = [10,5,7,10,13,12,7,3,3]
other_total = [
    0,   # <18
    6,   # 18–24
    6,   # 25–29
    4,   # 30–34
    8,   # 35–39
    12,  # 40–44
    14,  # 45–49
    16,  # 50–54
    14,  # 55–59
    6,   # 60–64
    3,   # 65–69
    0    # 70+
]
other_female = round.(Int, other_total .* 0.80)
other_male   = other_total .- other_female

sum(other_total)

#--------finding offices with 20 or more people---------------
data_settings = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2")["data"]
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
JLD2.@save "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_example.jld2" data
newpeople = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_example.jld2")["data"]

subset(newpeople,:occupation => ByRow(x -> x > 1000), skipmissing=true) |>vscodedisplay
############------------------###########################
##
vscodedisplay(offices)