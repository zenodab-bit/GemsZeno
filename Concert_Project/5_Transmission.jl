# ===========================================================================
# 5_Transmission.jl
#
# Extends GEMS's transmission_probability for SettingRate. For ordinary
# settings, returns the infecter's own transmission_prob. For GlobalSetting
# (mass gatherings), only returns it if infecter and infected share the
# same event and section on this tick; otherwise 0.
# ===========================================================================

import GEMS.transmission_probability

# general_rate is required by GEMS's config parser (the TOML's
# transmission_function block) but not read anywhere below — confirmed by
# testing, transmission_prob (set per-person in 3_Population.jl) is what
# actually governs transmission.
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

    # must be same event (any section — see cross-section contacts in 4_Contacts.jl)
    if infecter.category_ids[idx_a] == infected.category_ids[idx_b] &&
       infecter.draw_ids[idx_a] == infected.draw_ids[idx_b]
        return infecter.transmission_prob
    end

    return 0.0
end


println("End Transmission")