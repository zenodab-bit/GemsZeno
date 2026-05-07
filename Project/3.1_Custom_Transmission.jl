##
import GEMS.transmission_probability

# Define a custom struct for setting-specific transmission rates
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64    # Transmission rate for non-GlobalSetting settings
    sitting_rate::Float64    # Transmission rate for sitting individuals in GlobalSetting
    standing_rate::Float64   # Transmission rate for standing individuals in GlobalSetting
end

# Override the transmission probability function for the SettingRate struct
function GEMS.transmission_probability(transFunc::SettingRate,
    infecter::Individual, infected::Individual,
    setting::Setting, tick::Int16)::Float64

    # If not in GlobalSetting, use the general transmission rate
    if !(setting isa GEMS.GlobalSetting)
        return transFunc.general_rate
    end

    # Logic for GlobalSetting (concert) on day 5
    if tick == 30
        # Transmission only occurs between individuals in the same section
        if infecter.occupation == 1 && infected.occupation == 1
            return transFunc.sitting_rate  # Both are sitting
        elseif infecter.occupation == 2 && infected.occupation == 2
            return transFunc.standing_rate  # Both are standing
        else
            return 0  # Different sections (no transmission)
        end
    else
        return 0  # No transmission outside of concert day
    end
end
## end
print("END CUSTOM TRANSMISSION")