## === Setup ===

#all the packages we will need
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO, 
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

#load the people dataset
people = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/people_Saalekreis.jld2")["data"]

#load the setting dataset
data_settings = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/settings_Saalekreis.jld2")["data"]