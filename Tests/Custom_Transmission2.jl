##
import GEMS.transmission_probability

# define custom transmission struct
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64
    seated_rate::Float64
    standing_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if the agent has already been infected (natural immunity)
    if number_of_infections(infected) > 0
        return 0.0
    end

    #if the contact section is at the concert while seated, return seated_rate
        ##if it is at the concert while standing, return standing_rate
        ##elsem return the general_rate
    if tick == 45
        return transFunc.seated_rate
    else
        return transFunc.general_rate
    end

end
##