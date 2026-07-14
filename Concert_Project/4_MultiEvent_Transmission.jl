# Define a custom struct to store setting-specific transmission rates
# Inherits from GEMS.TransmissionFunction to override default behavior
@with_kw mutable struct SettingRate <: GEMS.TransmissionFunction
    general_rate::Float64
    event_dates::Set{Int16} = Set{Int16}()
end

function GEMS.transmission_probability(
    transFunc::SettingRate,
    infecter::Individual,
    infected::Individual,
    setting::Setting,
    tick::Int16
)::Float64

    if -1 < recovery(infected) <= tick
        return 0.0
    end

    if !(setting isa GEMS.GlobalSetting)
        return transFunc.general_rate
    end

    # fast check - is this tick an event day?
    if !(tick in transFunc.event_dates)
        return 0.0
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