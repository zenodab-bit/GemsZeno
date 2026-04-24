##
# define custom transmission struct
@with_kw struct SettingRate <: TransmissionFunction
household_rate::Float64
schoolclass_rate::Float64 
schoolyear_rate::Float64
schoolcomplex_rate::Float64
school_rate::Float64
office_rate::Float64
department_rate::Float64
workplacesite_rate::Float64
workplace_rate::Float64
municipality_rate::Float64
global_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(
transFunc::SettingRate,
infecter::Individual,
infected::Individual,
setting::Setting,
tick::Int16
)::Float64

# natural immunity
if number_of_infections(infected) > 0
return 0.0
end

if isa(setting, Household)
return transFunc.household_rate

elseif isa(setting, SchoolClass)
return transFunc.schoolclass_rate

elseif isa(setting, SchoolYear)
return transFunc.schoolyear_rate

elseif isa(setting, SchoolComplex)
return transFunc.schoolcomplex_rate

elseif isa(setting, School)
return transFunc.school_rate

elseif isa(setting, Office)
return transFunc.office_rate

elseif isa(setting, Department)
return transFunc.department_rate

elseif isa(setting, WorkplaceSite)
return transFunc.workplacesite_rate

elseif isa(setting, Workplace)
return transFunc.workplace_rate

elseif isa(setting, Municipality)
return transFunc.municipality_rate

elseif isa(setting, GlobalSetting)
return transFunc.global_rate

else
return 0.0 # safe fallback
end
end
###########################

##
sim_Saalekreis_Hospital = Simulation(
    configfile = "/home/bernaze/GemsZeno/Project/toml/influenza_hh_012.toml",
    population = "/home/bernaze/GemsZeno/Project/Datastorage/people_Saalekreis_example.jld2", 
    settingsfile = "/home/bernaze/GemsZeno/Project/Datastorage/settings_Saalekreis.jld2",
    label = "Hospital simulation")
run!(sim_Saalekreis_Hospital)
rd_Saalekreis_Hospital = ResultData(sim_Saalekreis_Hospital)