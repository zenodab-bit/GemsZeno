##

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