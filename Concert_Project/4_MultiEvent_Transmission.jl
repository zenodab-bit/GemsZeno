# Define a custom struct to store setting-specific transmission rates
# Inherits from GEMS.TransmissionFunction to override default behavior
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64
end

function GEMS.transmission_probability(
    transFunc::SettingRate,    # Custom transmission rate struct
    infecter::Individual,      # Individual who may transmit the infection
    infected::Individual,      # Individual who may become infected
    setting::Setting,           # Current setting
    tick::Int16                 # Current simulation time step
)::Float64

    if  -1 < recovery(infected) <= tick 
        return 0.0
    end
    
    # For non-concert settings, use the general transmission rate
    if !(setting isa GEMS.GlobalSetting)
        return transFunc.general_rate
    end

    if tick == infecter.event_date
        if infecter.event_id == infected.event_id && infecter.event_id != -1
            if infecter.section_id == infected.section_id
                return transFunc.general_rate
            end
        end
        return 0.0
    end
    return 0.0
end