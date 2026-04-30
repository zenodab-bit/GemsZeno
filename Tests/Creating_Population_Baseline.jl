## === Load all the packages and datasets ===

#all the packages we will need
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO, 
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

#load the people dataset
people = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis.jld2")["data"]

#load the setting dataset
data_settings = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2")["data"]






## === Setup and configure all the Parameters ===

#here we specify the total number of partecipant at the event
event_size_total = 1159


#here we specify the percentage of seated / standing people
concert_groups_percentage = [0.6, 0.4]

#or we can specify the exact number of people seated/standing
concert_groups_number = [583, 576]

#code for type of Attendance
    #we will use -1 for people not partecipating
    #1 for people seated and 2 for people standing
concert_attendance_levels = [1, 2]

#and say if we want to use the number or the percentage
concert_groups_number_true = true


#here we specify the sex group division as a percentage male / female
sex_groups_percentage = [0.366 , 0.634]

#sex levels
sex_levels = [1, 2]


#here we specify the age group division as a percentage
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

#we create a function to calculate how many people to put in each group
    #that gives only integers as result, while misplacing the least
    #amount of individuals
function nice_split(total, groups_percentage_temp)
    #calculate the raw (not necessarily an integer) number of individuals in each group
    groups_vector_raw = total * groups_percentage_temp

    #calculate the ceil (integer) needed to contain all the people
    total_from_raw = ceil(sum(groups_vector_raw))

    #floor all the values, to get integers
    groups_vector = floor.(Int, groups_vector_raw)

    #calculate how many individuals have not being places
    remainder = total_from_raw - sum(groups_vector)

    #calculate the decimals
    decimals = groups_vector_raw .- groups_vector

    #order them from largest to smallest
    idx = sortperm(vec(decimals), rev= true)

    #starting from the group that was closer to the next integer (i.e. largest remainder), add one element
        #repeat as many time as elements missing
    for i in 1:Int(remainder)
        idx_3D = CartesianIndices(decimals)[idx[i]]
        groups_vector[idx_3D] += 1
    end

    #return the vectors containing the numbers of individuals in each group
    return groups_vector

end

#depending if we have a number or percentage for the categories
    #we split the population into seated / standing
if concert_groups_number_true == true
    concert_groups = concert_groups_number
else
    concert_groups = concert_groups_percentage
end

#we keep percentages until the very end
    #we create a matrix to store the groups percentages
groups_percentage = zeros(Float64,length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

#for each concert setting (i.e standing or sitting, or different sectors)
for loc in eachindex(concert_groups)
    #for each age group
    for i in eachindex(age_groups_percentage)
        #for each sex group
        for j in eachindex(sex_groups_percentage)
            #we calculate how many people (as a percentage) go into this specific group 
                #given by setting, age and gender
            groups_percentage[loc, i, j] = concert_groups[loc] * age_groups_percentage[i] * sex_groups_percentage[j]

        end
    end
end

#we need to store all those numbers
groups_total = zeros(Int,length(concert_groups), length(age_groups_percentage), length(sex_groups_percentage))

#check if we have percentages or numbers of partecipant
if concert_groups_number_true == true
    #if true we already have numbers of partecipants, not percentages
        #we just need to transform them to integers
    groups_total = nice_split(1, groups_percentage)
else
    #if not, calculate the number needed
    groups_total = nice_split(event_size_total, groups_percentage)
end





## === Assign people to each group

#reset occupation column, we will use this to store concert attendace. -1 represent not going
people.occupation .= -1

#function to assign individuals to a partecipation group by age group and sex
function assign_concert!(pop::DataFrame, groups_total, age_order, sex_levels, concert_attendance_levels)
    
    #for each different level/setting at the concert
    for (i, loc) in enumerate(concert_attendance_levels)
        #and for each age group
        for (j, age) in enumerate(age_order)
            #and for each sex group
            for (k, sex) in enumerate(sex_levels)
                
                #we check if it is an empty category 
                    #and we skip it if it is
                n = groups_total[i, j, k] 
                n == 0 && continue

                #if not, find eligible candidates
                candidates = findall(
                    (pop.age_group .== age) .&
                    (pop.sex .== sex) .&
                    (pop.occupation .== -1)
                    )

                #we check if there are enough candidates
                if length(candidates) < n
                    #if not return an error
                    error("Not enough candidates for (age=$age, sex=$sex, loc=$loc)")
                end

                #if we have enough candidates, pick them at random without replacement
                selected = sample(candidates, n; replace=false)

                #for those selected, assign their concert setting (i.e seated, standing)
                pop.occupation[selected] .= loc
            end
        end
    end

    #return our dataframe
    return pop
end

#run the function to assign people
assign_concert!(
    people,
    groups_total,
    age_order,
    sex_levels,
    concert_attendance_levels
)






## === Run some validation tests and plots

#count how many people are not going, oging and sitting, going and standing
countmap(people.occupation)
#count how many people are in a specific subgroup
sum((people.age_group .== "31-35") .& (people.sex .== 2) .& (people.occupation .== 1))

#store all people sitting
seated = people[people.occupation .== 1, : ]

#group sitting people by age
seated_counts = combine(
    groupby(seated, :age_group),
    nrow => :count
)

#change it to be a categorical variable
seated_counts.age_group = categorical(
    seated_counts.age_group;
    ordered = true,
    levels = age_order
)

#store al standing people
standing = people[people.occupation .== 2, :]

#group standing people by age
standing_counts = combine(
    groupby(standing, :age_group),
    nrow => :count
)

#change it to be a categorical variable
standing_counts.age_group = categorical(
    standing_counts.age_group;
    ordered = true,
    levels = age_order
)

sort!(seated_counts, :age_group)
sort!(standing_counts, :age_group)

using StatsPlots

#@df seated_counts bar(
#    :age_group,
#    :count,
#    xlabel = "Age group",
#    ylabel = "Number of seated",
#    title = "Number of seated people by Age Group",
#    legend = false,
#    bar_width = 0.7
#)


#@df standing_counts bar(
#    :age_group,
#    :count,
#    xlabel = "Age group",
#    ylabel = "Number of standing",
#    title = "Number of standing people by Age Group",
#    legend = false,
#    bar_width = 0.7
#)




## === Saving updated information ===

data = people
JLD2.@save "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2" data
newpeople = JLD2.load("/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_concert.jld2")["data"]

#subset(newpeople,:occupation => ByRow(x -> x == "Seated" || x == "Standing"), skipmissing=true) |>vscodedisplay

## === Lets remove some columns ===
#newpople_short = select!(newpeople, [:SchoolYear, :SchoolComplex, :Workplace, :WorkplaceSite, :Municipality, :Department])

## end
print("END CREATING POPULATION BASELINE")