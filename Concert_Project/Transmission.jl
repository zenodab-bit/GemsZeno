import GEMS.transmission_probability

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
        return infecter.transmission_prob
    end

    # fast check — is this tick an event day?
    if !(tick in transFunc.event_dates)
        return 0.0
    end

    # find infecter's event today
    isempty(infecter.event_dates) && return 0.0
    idx_a = findfirst(==(tick), infecter.event_dates)
    idx_a === nothing && return 0.0

    isempty(infected.event_dates) && return 0.0
    idx_b = findfirst(==(tick), infected.event_dates)
    idx_b === nothing && return 0.0

    # must be same event and same section
    if infecter.category_ids[idx_a] == infected.category_ids[idx_b] &&
       infecter.draw_ids[idx_a] == infected.draw_ids[idx_b] &&
       infecter.section_ids[idx_a] == infected.section_ids[idx_b]
        return infecter.transmission_prob
    end

    return 0.0
end



println("End Transmission")