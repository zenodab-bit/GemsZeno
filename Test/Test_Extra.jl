## Extra Test

using GEMS
using Parameters
import GEMS.transmission_probability

@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    household_rate::Float64
    general_rate::Float64
    office_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if the agent has already been infected (natural immunity)
    if number_of_infections(infected) > 0
        return 0.0
    end

    #if the contact setting is a household, return household_rate
    if isa(setting, Household)
        return transFunc.household_rate
    end
    return isa(setting, Office) ? transFunc.office_rate : transFunc.general_rate
    
end

default = Simulation(label = "default")
tf = SettingRate(general_rate = 0.1, household_rate = 0.3, office_rate = 0.5)
custom = Simulation(label = "custom transmission", transmission_function = tf)
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :TickCasesBySetting)

##