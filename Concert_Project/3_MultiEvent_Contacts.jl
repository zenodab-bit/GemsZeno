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

    if ego.event_id == -1
        return Individual[]
    end

    same_section_individuals = Vector{Individual}()
    for x in present_individuals
        if x.event_id == ego.event_id && x.section_id == ego.section_id && x != ego
            push!(same_section_individuals, x)
        end
    end

    isempty(same_section_individuals) && return Individual[]

    num_of_contacts = min(rand(rng, Poisson(ego.mean_event_contacts)), length(same_section_individuals))

    resize!(indivs, num_of_contacts)
    shuffled = shuffle(rng, same_section_individuals)
    for cnt in 1:num_of_contacts
        indivs[cnt] = shuffled[cnt]
    end
end