##Setup

using GEMS, Distributions, Plots





## Standard

#define the values for the Asymptomatic progression
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
#define the values for the Symptomatic progression
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

#we can now define an Assignment "rule" to the progression categories
pass = AgeBasedProgressionAssignment(
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[0.0, 1.0],
                                [1.0, 0.0]]
)

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gp = gemsplot(rd, type = :ProgressionCategories)
png(gp, "Progressio_0-14_Standard.png")







## Switched matrix

#define the values for the Asymptomatic progression
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
#define the values for the Symptomatic progression
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

#we can now define an Assignment "rule" to the progression categories
pass = AgeBasedProgressionAssignment(
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[1.0, 0.0],
                                [0.0, 1.0]]
)

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gp = gemsplot(rd, type = :ProgressionCategories)
png(gp, "Progressesion_0-14_switched.png")







## Age groups 50/50

#define the values for the Asymptomatic progression
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
#define the values for the Symptomatic progression
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

#we can now define an Assignment "rule" to the progression categories
pass = AgeBasedProgressionAssignment(
    age_groups = ["0-45","46-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[0.0, 1.0],
                                [1.0, 0.0]]
)

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gp = gemsplot(rd, type = :ProgressionCategories)
png(gp, "Progression_0-45_Standard.png")





## Age groups 50/50 Switched

#define the values for the Asymptomatic progression
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
#define the values for the Symptomatic progression
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

#we can now define an Assignment "rule" to the progression categories
pass = AgeBasedProgressionAssignment(
    age_groups = ["0-45","46-"],
    progression_categories = ["Asymptomatic", "Symptomatic"],
    stratification_matrix = [[1.0, 0.0],
                                [0.0, 1.0]]
)

p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gp = gemsplot(rd, type = :ProgressionCategories)
png(gp, "Progression_0-45__switched.png")