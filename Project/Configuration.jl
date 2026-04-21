## === Load all the packages and datasets ===

#all the packages we will need
using GEMS, Parameters, DataFrames, TOML, Plots, FileIO, 
    Distributions, CSV, CategoricalArrays, JLD2, Random,
    StatsBase

#load the people dataset
people = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/people_Saalekreis.jld2")["data"]

#load the setting dataset
data_settings = JLD2.load("/home/bernaze/GemsZeno/Saalekreis-20260417T095425Z-3-001/Saalekreis/settings_Saalekreis.jld2")["data"]

## === Setup and configure all the Parameters ===

#here we specify the total number of partecipant at the event
event_size_total = 1212

#here we specify the percentage of seated / standing people
concert_groups_percentage = [0.6, 0.4]

#or we can specify the exact number of people seated/standing
concert_groups_number = [400, 600]

#and say if we want to use the number or the percentage
concert_group_number_true = false

#here we specify the sex group division as a percentage male / female
sex_groups_percentage = [0.366 , 0.634]

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

#code for type of Attendance
concert_attendance_levels = [1, 2]
no_attendance = -1
seated  = 1
standing  = 2

#sex levels
sex_levels = [1, 2]

## Call the functions

include("Functions.jl")


