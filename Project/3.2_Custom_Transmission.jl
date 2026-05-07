##
import GEMS.transmission_probability

# define custom transmission struct
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64
    seated_rate::Float64
    standing_rate::Float64
    null_rate::Float64
end

# override transmission probability function for your struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # If not in GlobalSetting, use the general rate (default transmission)
    if !(setting isa GEMS.GlobalSetting)
        return transFunc.general_rate  # or 0.05 (from your config)
    end

    # Your existing logic for GlobalSetting (concert)
    if tick == 5
        if infecter.occupation == 1 && infected.occupation == 1
            return transFunc.seated_rate
        elseif infecter.occupation == 2 && infected.occupation == 2
            return transFunc.standing_rate
        else
            return 0
        end
    else
        return 0
    end
end
## end
print("END CUSTOM TRANSMISSION")