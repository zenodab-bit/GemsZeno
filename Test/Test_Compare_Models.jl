## SETUP
#load the package manager Pkg
using Pkg
#use it to add the package GEMS from the github
Pkg.add(url = "https://github.com/IMMIDD/GEMS")
#load the package GEMS
using GEMS

## BASE TWO SIMULATIONS
#create the object simulation, where we store all necessary information
sim1 = Simulation(label = "Baseline")
#run the simulation step by step
run!(sim1)
#store the results of interest
rd1 = ResultData(sim1)
#plot the results of interest
gemsplot(rd1)

#we create and run a second simulation,
    #trying values different from the first one

#create the object simulation, where we store all necessary information
sim2 = Simulation(transmission_rate = 0.3, avg_household_size = 5, label = "More Infectious")
#run the simulation step by step
run!(sim2)
#store the results of interest
rd2 = ResultData(sim2)
#plot the results of interest
gemsplot(rd2)

#and we can plot them togheter
gemsplot([rd1, rd2])
#or plot them side by side
gemsplot([rd1, rd2], combined = :bylabel)