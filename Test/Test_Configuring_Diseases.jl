##Setup

using GEMS, Distributions

#we can display the available progression categories
progression_categories()

#we can change the values for one (or more) categories
symp = Symptomatic(
    exposure_to_infectiousness_onset = 1,
    infectiousness_onset_to_symptom_onset = 1,
    symptom_onset_to_recovery = 7
)

#we define a new pathogen using our progression
p = Pathogen(
    name = "10Day-Disease",
    progressions = [symp]
)

#and run the simulation using our new pathogen
sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))

## Multiple progressions

#we do the same as before, but we can use more than just the Symptomatic category
    #and we can use distributions instead of fixed numbers
#we define the values for Asymptomatic progression
asymp = Asymptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_recovery = Poisson(2))
#and for Symptomatic progression
symp = Symptomatic(
    exposure_to_infectiousness_onset = Poisson(1), # 1+1
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

#and define our pathogento use the two progressions
p = Pathogen(
name = "Two-Peaks-Disease",    
progressions = [asymp, symp])

#run the simulation
sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))

## Age-based Progression Assignment

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

#and define our pathogen
p = Pathogen(
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp],
    progression_assignment = pass)

sim = Simulation(pathogen = p)
run!(sim)
rd = ResultData(sim)
gemsplot(rd, type = (:TickCases, :InfectionDuration, :ProgressionCategories))
