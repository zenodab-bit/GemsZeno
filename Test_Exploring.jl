## Setup

#load the package manager Pkg
using Pkg
#use it to add the package GEMS from the github
Pkg.add(url = "https://github.com/IMMIDD/GEMS")
#load the package GEMS
using GEMS

#load the package plots
using Plots

## Base simulation

#create the object simulation, where we store all necessary information
sim = Simulation(label = "Baseline")
#run the simulation step by step
run!(sim)
#store the results of interest
rd1 = ResultData(sim)
#plot the results of interest
gemsplot(rd)


## DATA EXPLORATION
#we can get and visualize the raw data in table form)
df = sim |> infectionlogger |> dataframe
vscodedisplay(df)

## EXPLORING INDIVIDUALS
#extract the individuals from the simulation as a vector of individuals
individuals(sim)
#and we can save it in an objext
inds = individuals(sim)
#and then we can extract a particular attribute
age.(inds)

#or we can get a Population object
pop = population(sim)
#and we visualize it
dataframe(pop)

## Single individual

#we can check individual's status, like infection of the first individual
#take the first individual
first_ind = individuals(sim) |> first
#check if it is infected
infected(first_ind)

#in a similar way we can change individuals' attribute values
#take the first individual
first_ind = individuals(sim) |> first
#check the age
age(first_ind)
#change it
first_ind.age = 15
#check again
age(first_ind)

#we can find out the household of the subject
household(first_ind, sim)

## Single second individual

#i want to try the same but on a different individual, like the second one
#take the second individual
second_ind = individuals(sim)[2]
#check the age
age(second_ind)
#change it
second_ind.age = 15
#check again
age(second_ind)

## Exploring Settings

#extract the type and list of settings
settings(sim)
#or we can extract one specific setting type
households(sim)
#we can save it
hhlds = households(sim)
#extract and save the sizes of all household
hh_sizes = size.(hhlds)
#and plot them
histogram(hh_sizes, xlabel = "Household Size", label = "Number of Household")

## Traversing

#we still want an individual, lets take the first one
first_ind = individuals(sim) |> first
#find the household of the individual
hh = household(first_ind, sim)
#now we can find the other members of the family
hh_members = individuals(hh)
#and get their id
id.(hh_members)
