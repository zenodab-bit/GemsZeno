import GEMS: sample_contacts!


# === NegBin Contact Sampling for normal settings ===

@with_kw mutable struct NegBinContacts <: GEMS.ContactSamplingMethod
    mean_contacts::Float64
    std_contacts::Float64
end

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

@with_kw mutable struct EventContacts <: GEMS.ContactSamplingMethod
    contactparameter::Float64 = 0.0
    cached_tick::Int16 = Int16(-1)
    rosters::Dict{Tuple{Int32,Int32,Int32},Vector{Individual}} = Dict{Tuple{Int32,Int32,Int32},Vector{Individual}}()
end

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

    # rebuild the roster once per tick — shared across every ego that calls this on the same day
    if event_contacts.cached_tick != tick
        empty!(event_contacts.rosters)
        for x in present_individuals
            isempty(x.event_dates) && continue
            jdx = findfirst(==(tick), x.event_dates)
            jdx === nothing && continue
            key = (x.category_ids[jdx], x.draw_ids[jdx], x.section_ids[jdx])
            push!(get!(() -> Individual[], event_contacts.rosters, key), x)
        end
        event_contacts.cached_tick = tick
    end

    idx = findfirst(==(tick), ego.event_dates)
    idx === nothing && return indivs

    key = (ego.category_ids[idx], ego.draw_ids[idx], ego.section_ids[idx])
    roster = get(event_contacts.rosters, key, nothing)
    roster === nothing && return indivs

    others = filter(x -> x !== ego, roster)
    isempty(others) && return indivs

    num_of_contacts = min(
        sample_n_contacts(rng, ego.mean_event_contacts[idx], ego.std_event_contacts[idx]),
        length(others)
    )
    num_of_contacts <= 0 && return indivs

    chosen = sample(rng, others, num_of_contacts, replace=false)
    resize!(indivs, num_of_contacts)
    for i in 1:num_of_contacts
        indivs[i] = chosen[i]
    end

    return indivs
end


println("End Contacts")