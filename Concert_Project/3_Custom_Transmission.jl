## === Define Custom Transmission Function ===

# Import the base transmission probability function from GEMS
import GEMS.transmission_probability

# Define a custom struct to store setting-specific transmission rates
# Inherits from GEMS.TransmissionFunction to override default behavior
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64    # Default transmission rate for non-concert settings
    sitting_rate::Float64    # Transmission rate for sitting individuals in concert
    standing_rate::Float64   # Transmission rate for standing individuals in concert
end




## === Implement Transmission Probability Logic ===

# Override the default transmission probability function
# Determines the probability of transmission between two individuals in a given setting and time
function GEMS.transmission_probability(
    transFunc::SettingRate,    # Custom transmission rate struct
    infecter::Individual,      # Individual who may transmit the infection
    infected::Individual,      # Individual who may become infected
    setting::Setting,           # Current setting
    tick::Int16                 # Current simulation time step
)::Float64

    if  -1 < recovery(infected) <= tick # if the agent has already recovered (natural immunity)
        return 0.0
    end
    
    # For non-concert settings, use the general transmission rate
    if !(setting isa GEMS.GlobalSetting)
        return transFunc.general_rate
    end

    # For concert settings, only allow transmission on the concert day
    if tick == concert_date
        # Transmission is only possible between individuals in the same concert section
        if infecter.occupation == 1 && infected.occupation == 1
            return transFunc.sitting_rate  # Both are sitting
        elseif infecter.occupation == 2 && infected.occupation == 2
            return transFunc.standing_rate  # Both are standing
        else
            return 0.0  # Different sections: no transmission
        end
    else
        return 0.0  # No transmission outside the concert day
    end
end


## END
println("\nEND CUSTOM TRANSMISSION 3")