# ===========================================================================
# 4_Contacts.jl
#
# Extends GEMS's sample_contacts! for two ContactSamplingMethods, dispatched
# by the "type" set in each setting's TOML config: NegBinContacts for
# ordinary settings (household, office, etc.), EventContacts specifically
# for GlobalSetting (mass gatherings).
# ===========================================================================

import GEMS: sample_contacts!


# === NegBin Contact Sampling for normal settings ===

@with_kw mutable struct NegBinContacts <: GEMS.ContactSamplingMethod
    mean_contacts::Float64
    std_contacts::Float64
end

# Draws n contacts (via sample_n_contacts) from present_individuals,
# excluding ego, using distinct offsets so no contact repeats and none is ego.
function GEMS.sample_contacts!(
    indivs::Vector{Individual},
    csm::NegBinContacts,
    setting::Setting,
    individual_index::Int,
    present_individuals::Vector{Individual},
    tick::Int16,
    replace::Bool,
    rng::Xoshiro
)
    empty!(indivs)
    length(present_individuals) <= 1 && return indivs

    n_contacts = min(sample_n_contacts(rng, csm.mean_contacts, csm.std_contacts), length(present_individuals) - 1)
    n_contacts <= 0 && return indivs

    # distinct offsets => distinct contacts, and offset never lands on ego (offset ∈ 1:length-1, mod length)
    offsets = sample(rng, 1:(length(present_individuals)-1), n_contacts, replace=false)

    resize!(indivs, n_contacts)
    for i in 1:n_contacts
        contact_index = mod(individual_index + offsets[i] - 1, length(present_individuals)) + 1
        indivs[i] = present_individuals[contact_index]
    end

    return indivs
end


# === Event Contact Sampling ===

# rosters is rebuilt once per tick (see below), shared across every call
# that tick rather than rescanning the whole population per call.
@with_kw mutable struct EventContacts <: GEMS.ContactSamplingMethod
    contactparameter::Float64 = 0.0
    cached_tick::Int16 = Int16(-1)
    rosters::Dict{Tuple{Int32,Int32,Int32},Vector{Individual}} = Dict{Tuple{Int32,Int32,Int32},Vector{Individual}}()
    draw_rosters::Dict{Tuple{Int32,Int32},Vector{Individual}} = Dict{Tuple{Int32,Int32},Vector{Individual}}()
end

# Finds ego's event (if any) for this tick, then draws contacts from others
# in the same (category, draw, section). Builds/caches a roster of every
# attendee keyed by (category_id, draw_id, section_id) the first time this
# tick is seen, so repeated calls the same day reuse it instead of
# rescanning present_individuals each time.
function GEMS.sample_contacts!(
    indivs::Vector{Individual},
    event_contacts::EventContacts,
    setting::GEMS.GlobalSetting,
    individual_index::Int,
    present_individuals::Vector{Individual},
    tick::Int16,
    replace::Bool,
    rng::Xoshiro
)
    empty!(indivs)
    ego = present_individuals[individual_index]

    if event_contacts.cached_tick != tick
        empty!(event_contacts.rosters)
        empty!(event_contacts.draw_rosters)
        for x in present_individuals
            isempty(x.event_dates) && continue
            jdx = findfirst(==(tick), x.event_dates)
            jdx === nothing && continue
            section_key = (x.category_ids[jdx], x.draw_ids[jdx], x.section_ids[jdx])
            draw_key = (x.category_ids[jdx], x.draw_ids[jdx])
            push!(get!(() -> Individual[], event_contacts.rosters, section_key), x)
            push!(get!(() -> Individual[], event_contacts.draw_rosters, draw_key), x)
        end
        event_contacts.cached_tick = tick
    end

    idx = findfirst(==(tick), ego.event_dates)
    idx === nothing && return indivs

    section_key = (ego.category_ids[idx], ego.draw_ids[idx], ego.section_ids[idx])
    draw_key = (ego.category_ids[idx], ego.draw_ids[idx])

    section_roster = get(event_contacts.rosters, section_key, nothing)
    same_section_others = section_roster === nothing ? Individual[] : filter(x -> x !== ego, section_roster)

    # within-section contacts, using this attendee's own section rate
    n_within = min(sample_n_contacts(rng, ego.mean_event_contacts[idx], ego.std_event_contacts[idx]), length(same_section_others))
    if n_within > 0
        append!(indivs, sample(rng, same_section_others, n_within, replace=false))
    end

    # cross-section contacts, using the category's cross-section rate (0 by
    # default keeps sections fully isolated, matching prior behavior)
    if ego.cross_section_mean_contacts[idx] > 0
        draw_roster = get(event_contacts.draw_rosters, draw_key, nothing)
        if draw_roster !== nothing
            same_section_set = Set(section_roster === nothing ? Individual[] : section_roster)
            cross_others = filter(x -> x !== ego && x ∉ same_section_set, draw_roster)
            n_cross = min(sample_n_contacts(rng, ego.cross_section_mean_contacts[idx], ego.cross_section_std_contacts[idx]), length(cross_others))
            if n_cross > 0
                append!(indivs, sample(rng, cross_others, n_cross, replace=false))
            end
        end
    end

    return indivs
end

println("End Contacts")