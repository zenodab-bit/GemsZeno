##
#import the transmission_probabilityfunction from GEMS to override it
import GEMS.transmission_probability

# define custom transmission struct
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    #base transmission rate for general (non-concert) settings
    general_rate::Float64

    #transmission rate for seated individuals
    seated_rate::Float64
    
    #transmission rate for standing individuals
    standing_rate::Float64

end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # if the agent has already been infected (natural immunity) it has natural immunity
    if number_of_infections(infected) > 0
        return 0.0
    end

    #at the concert tick
    if tick == 45

        #if both individuals are seated return seated transmission
        if infecter.occupation == 1 && infected.occupation == 1
            return transFunc.seated_rate

        #else if both are standing return standing transmission
        elseif infecter.occupation == 2 && infected.occupation == 2
            return transFunc.standing_rate
        else
            return transFunc.general_rate
        end
    else
        #for all other timestep, use the general transmission rate
        return transFunc.general_rate
    end

end
## end
print("END CUSTOM TRANSMISSION")