## Setup

using GEMS
sim = Simulation(configfile = "C:/Users/Zeno/.vscode/Projects/GemsZeno/config.toml")



## Comparing two simulations
using GEMS
default = Simulation(label = "default", global_setting = true)

custom = Simulation(label = "custom global contacts", global_setting = true, configfile = "C:/Users/Zeno/.vscode/Projects/GemsZeno/config.toml")
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :AggregatedSettingAgeContacts)

## Custom Transmission Functions

using GEMS
using Parameters
import GEMS.transmission_probability

@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    household_rate::Float64
    general_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if the agent has already been infected (natural immunity)
    if number_of_infections(infected) > 0
        return 0.0
    end

    # if the contact setting is a household, return household_rate
    # and the general_rate otherwise
    return isa(setting, Household) ? transFunc.household_rate : transFunc.general_rate
end

default = Simulation(label = "default")
tf = SettingRate(general_rate = 0.1, household_rate = 0.3)
custom = Simulation(label = "custom transmission", transmission_function = tf)
run!(default)
run!(custom)
rd_d = ResultData(default)
rd_c = ResultData(custom)
gemsplot([rd_d, rd_c], type = :TickCasesBySetting)

