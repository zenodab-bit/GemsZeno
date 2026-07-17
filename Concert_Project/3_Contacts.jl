import GEMS: sample_contacts!
using Random: Xoshiro, shuffle

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

    r, p = negbin_params(csm.mean_contacts, csm.std_contacts)
    n_contacts = min(rand(rng, NegativeBinomial(r, p)), length(present_individuals) - 1)

    resize!(indivs, n_contacts)
    for i in 1:n_contacts
        offset = rand(rng, 1:length(present_individuals)-1)
        contact_index = mod(individual_index + offset - 1, length(present_individuals)) + 1
        indivs[i] = present_individuals[contact_index]
    end
end


# === Event Contact Sampling ===

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

    today_category_id = ego.category_ids[idx]
    today_event_id    = ego.event_ids[idx]
    today_section_id  = ego.section_ids[idx]
    today_contacts    = ego.mean_event_contacts[idx]
    today_std         = ego.std_event_contacts[idx]

    same_section_individuals = Vector{Individual}()
    for x in present_individuals
        x == ego && continue
        isempty(x.event_dates) && continue
        jdx = findfirst(==(tick), x.event_dates)
        jdx === nothing && continue
        if x.category_ids[jdx] == today_category_id &&
           x.event_ids[jdx] == today_event_id &&
           x.section_ids[jdx] == today_section_id
            push!(same_section_individuals, x)
        end
    end

    isempty(same_section_individuals) && return Individual[]

    r, p = negbin_params(today_contacts, today_std)
    num_of_contacts = min(
        rand(rng, NegativeBinomial(r, p)),
        length(same_section_individuals)
    )

    resize!(indivs, num_of_contacts)
    shuffled = shuffle(rng, same_section_individuals)
    for cnt in 1:num_of_contacts
        indivs[cnt] = shuffled[cnt]
    end
end