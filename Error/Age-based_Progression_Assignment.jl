## First test
#this is an almost identical copy to the code offered in tutorial 4- Configuring diseases
    #specifically under Age-based Progression Assignment
    #the only difference is in the plotted graphs,
    #I am interested in the Progression Cateogories, so only that graph is being plotted
using GEMS, Distributions 
asymp = Asymptomatic( 
    exposure_to_infectiousness_onset = Poisson(1),
    infectiousness_onset_to_recovery = Poisson(2))

symp = Symptomatic( 
    exposure_to_infectiousness_onset = Poisson(1),
    infectiousness_onset_to_symptom_onset = Poisson(2),
    symptom_onset_to_recovery = Poisson(14))

pass = AgeBasedProgressionAssignment( 
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic","Symptomatic"],
    stratification_matrix = [[0.0,1.0],
                            [1.0,0.0]])

 p = Pathogen( 
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp], 
    progression_assignment = pass) 
    
sim = Simulation(pathogen = p) 
run!(sim) 
rd = ResultData(sim) 
gemsplot(rd, type = (:ProgressionCategories))

#From the first graph, we see that in the ages between 0 and 14 there are no Asymptomatic
    #then, from the age 15 onwards, we start seeing some Asymptomatic, while there are no
    #more Symptomatic individuals
    #(Graph Progression_0-14_Standard)

## Second test
#here we keep the previous code for symptomati and Asymptomatic
    #but we change how the age groups are distributed in the two Cateogories
    #in particular, I´am swapping the number in the stratification matrix
    #from ([0 ,1] , [1 ,0]) to ([1 ,0], [0, 1])
    
#to my understanding, we should now see zero individuals from age 0 to 14
    #in the symptomatic group
    #and yero Asymptomatic from 15+
pass1 = AgeBasedProgressionAssignment( 
    age_groups = ["0-14","15-"],
    progression_categories = ["Asymptomatic","Symptomatic"],
    stratification_matrix = [[1.0, 0.0],
                            [0.0, 1.0]])

 p1 = Pathogen( 
    name = "Two-Peaks-Disease",
    progressions = [asymp, symp], 
    progression_assignment = pass1) 
    
sim1 = Simulation(pathogen = p1) 
run!(sim1) 
rd1 = ResultData(sim1) 
gemsplot(rd1, type = (:ProgressionCategories))

#the graph that I obtain shows instead Symptomatic individuals from age 0 to 79
    #and Asymptomatic fro age 79+
    #(Graph Progression_0-14_Switched)