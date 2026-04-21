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

#we create a function to split nicely people into groups while keeping the exact total number,
    #and respecting as close as possible the ratio between groups
function nice_split(total, groups_percentage_temp)
    #calculate the raw (not necessarily an integer) number of individuals in each group
    groups_vector_raw = total * groups_percentage_temp

    #floor all the values, to get integers
    groups_vector = floor.(Int, groups_vector_raw)

    #calculate how many missing partecipants
    remainder = total - sum(groups_vector)

    #calculate the decimals
    decimals = groups_vector_raw .- groups_vector

    #order them from largest to smallest
    idx = sortperm(vec(decimals), rev= true)

    #starting from the group that was closer to the next integer, add one element
        #repeat for each element missing
    for i in 1:remainder
        idx_3D = CartesianIndices(decimals)[idx[i]]
        groups_vector[idx_3D] += 1
    end

    return groups_vector

end

#decide if we have true numbers or percentages for locations
#we split the population into seated / standing
if location_group_true == true
    location_groups = location_groups_number
else
    location_groups = nice_split(event_size_total, location_groups_percentage)
end

#we keep percentage until the very end
groups_percentage = zeros(Float64,length(location_groups), length(age_groups_percentage), length(sex_groups_percentage))

for loc in eachindex(location_groups)

    for i in eachindex(age_groups_percentage)

        for j in eachindex(sex_groups_percentage)

            groups_percentage[loc, i, j] = location_groups_percentage[loc] * age_groups_percentage[i] * sex_groups_percentage[j]

        end
    end

end

#now we calculate the total number of people in each group
groups_total = nice_split(event_size_total, groups_percentage)

println("The Groups Percentages are: ", groups_percentage)
println(" ")
print("The Groups Total are: ", groups_total)
##

# Reset occupation column
people.occupation .= 0

#function to assign by age group and sex
function assign_concert!(pop::DataFrame, groups_total, age_order, sex_levels, location_levels)
    
    for (i, loc) in enumerate(location_levels)
        for (j, age) in enumerate(age_order)
            for (k, sex) in enumerate(sex_levels)

                n = groups_total[i, j, k]
                #skip if nothing to assign
                n == 0 && continue

                # find eligible candidates
                candidates = findall(
                    (pop.age_group .== age) .&
                    (pop.sex .== sex) .&
                    (pop.occupation .== 0)
                )

                if length(candidates) < n
                    error("Not enough candidates for (age=$age, sex=$sex, loc=$loc)")
                end

                selected = sample(candidates, n; replace=false)

                pop.occupation[selected] .= loc
            end
        end
    end

    return pop
end

##
assign_concert!(
    people,
    groups_total,
    age_order,
    sex_levels,
    locations_levels
)

countmap(people.occupation)
sum((people.age_group .== "31-35") .& (people.sex .== 1) .& (people.occupation .== 1))