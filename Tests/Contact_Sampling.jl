## === Start ===

#define a custom struct for concert contact sampling,
    #inheriting from ContactSamplingMethod in GEMS
@with_kw struct ConcertContacts <: ContactSamplingMethod
    #choose the distribution type for sampling the contacts
    distribution::String = "Poisson"

    #mean number of contacts for seated individuals
    mean_number_of_contacts_seated::Float64
    #mean number of contacts for standing individuals
    mean_number_of_contacts_standing::Float64

    #distribution fo seated contacts
    seDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_seated)
    #distribution of standing contacts
    stDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_standing)
end

#function to sample contacts for a given individual at the concert
function sample_contacts(
    concert_contacts::ConcertContacts,
    setting::Setting,
    ego::Individual,
    present_individuals::Vector{Individual},
    tick::Int16
)
    # Check if there are any individuals in the setting
    if isempty(present_individuals)
        throw(ArgumentError("No individuals are present. Please provide a list of individuals."))
    end

    # If only ego is present, return an empty list
    if length(present_individuals) == 1
        return Individual[]
    end

    # Filter to include only individuals in the same section as ego (and exclude ego)
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)
    isempty(same_section_individuals) && return Individual[]

    # Determine the number of contacts for ego based on their occupation
    num_of_contacts = if ego.occupation == 1
        rand(concert_contacts.seDistribution)
    elseif ego.occupation == 2
        rand(concert_contacts.stDistribution)
    else
        @warn "Individual $(ego.id) has invalid occupation $(ego.occupation). Assigning 0 contacts."
        0
    end

    # Sample contacts without replacement
    return sample(same_section_individuals, num_of_contacts; replace=false)
end

## end
print("END CONTACT SAMPLING")