import GEMS: sample_contacts!
using Random: Xoshiro, shuffle

@with_kw mutable struct EventContacts <: GEMS.ContactSamplingMethod
    contactparameter::Float64 = 0.0
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

    # find if ego is attending any event today
    idx = findfirst(==(tick), ego.event_dates)
    idx === nothing && return Individual[]

    today_event_id   = ego.event_ids[idx]
    today_section_id = ego.section_ids[idx]
    today_contacts   = ego.mean_event_contacts[idx]

    # filter to same event and section
    same_section_individuals = Vector{Individual}()
    for x in present_individuals
        x == ego && continue
        jdx = findfirst(==(tick), x.event_dates)
        jdx === nothing && continue
        if x.event_ids[jdx] == today_event_id && x.section_ids[jdx] == today_section_id
            push!(same_section_individuals, x)
        end
    end

    isempty(same_section_individuals) && return Individual[]

    num_of_contacts = min(
        rand(rng, Poisson(today_contacts)),
        length(same_section_individuals)
    )

    resize!(indivs, num_of_contacts)
    shuffled = shuffle(rng, same_section_individuals)
    for cnt in 1:num_of_contacts
        indivs[cnt] = shuffled[cnt]
    end
end