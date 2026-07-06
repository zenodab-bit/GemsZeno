# setup.jl — run once per machine to configure the environment
import Pkg
Pkg.activate(".")
Pkg.add(url="https://github.com/IMMIDD/GEMS")
Pkg.add(["Parameters", "DataFrames", "Distributions", "CSV", 
         "CategoricalArrays", "JLD2", "StatsBase", "Plots", "StatsPlots",
         "XLSX", "FileIO"])
println("Setup complete! You can now run the simulations.")
