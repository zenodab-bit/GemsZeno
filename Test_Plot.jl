## Setup

#load the package manager Pkg
using Pkg
#use it to add the package GEMS from the github
Pkg.add(url = "https://github.com/IMMIDD/GEMS")
#load the package GEMS
using GEMS

#load the package plots
using Plots

## Simulation

#create the object simulation, where we store all necessary information
sim = Simulation(label = "Baseline")
#run the simulation step by step
run!(sim)
#store the results of interest
rd1 = ResultData(sim)
#plot the results of interest
gemsplot(rd)

## Plotting

#we already plotted some graphs, we can now run plottypes() to get more
print(plottypes())

#we can plot for example cumulative cases by specifying the type in gemsplot
gemsplot(rd, type = :CumulativeCases)

#we can plot multiple types in the same plot
gemsplot(rd, type = (:CumulativeCases, :EffectiveReproduction))

#check the package Plots.jl for more customization, like:
    #we can plto the cumulative cases only for the first 100 days, with no legend
gemsplot(rd, type = :CumulativeCases, xlims = (0, 100), legend = false)
#or the cumulative cases from day 100 to 200
gemsplot(rd, type = :CumulativeCases, xlims = (100,200), legend = false)

## Custom Plots

#we can plot using the Plots.jl package if something is missing from gemsplot()
    #i.e we can visualize properties of the Simulation object, rather than the ResultData object
inds = individuals(sim)
ages = age.(inds)
histogram(ages, xlabel = "Age", ylabel = "Number of Individuals")

## Saving plots
gp = gemsplot(rd, type = :CumulativeCases)
png(gp, "cumulative_cases.png")

##Custom plot types

using GEMS, Parameters, DataFrames, Plots
import GEMS.generate

# This struct needs to be defined with the @with_kw macro
# and have default values for "title", "description", and "filename" 
@with_kw mutable struct TotalInfections <: GEMS.SimulationPlot
    title::String = "Total Infections"
    description::String = "This plot shows the total number of infections 
        throughout the span of the simulation." 
    filename::String = "total_infections.png"
end

# this function needs to take the new plot type, a ResultData object and optional plotargs...
function GEMS.generate(plt::TotalInfections, rd::ResultData; plotargs...)
    csum = rd |> tick_cases |>
        x -> transform(x, :exposed_cnt => cumsum => :exposed_cumsum)

    plot_cumsum = plot(xlabel="Ticks", ylabel="Total Infections")
    plot!(plot_cumsum, csum[!,"exposed_cumsum"], label="Infections")
    plot!(plot_cumsum; plotargs...) # optional, but let's the user pass custom arguments such as "xlims", etc...
    return(plot_cumsum)
end

# TESTING
sim = Simulation()
run!(sim)
rd = ResultData(sim)
gp = gemsplot(rd, type = :TotalInfections)