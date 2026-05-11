import GEMS: sample_contacts!
using Random: Xoshiro  # Ensure Xoshiro is imported

# Define a custom struct for concert contact sampling
mutable struct ConcertContacts <: GEMS.ContactSamplingMethod
end

# Override the mutating version of sample_contacts with explicit type constraints
function GEMS.sample_contacts!(
    indivs::Vector{Individual},
    concert_contacts::ConcertContacts,  # Explicitly use ConcertContacts
    setting::GEMS.GlobalSetting,           # Explicitly use GlobalSetting
    individual_index::Int,
    present_individuals::Vector{Individual},
    tick::Int16,
    replace::Bool,
    rng::Xoshiro  # Explicitly use Xoshiro instead of AbstractRNG
)
    empty!(indivs)
    # Get the ego individual
    ego = present_individuals[individual_index]

    # Skip if ego is not at the concert
    if ego.occupation != 1 && ego.occupation != 2
        return Individual[]
    end

    # Filter to include only individuals in the same section as ego (and exclude ego)
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)
    isempty(same_section_individuals) && return Individual[]

    # Define the mean number of contacts for sitting and standing individuals
    mean_number_of_contacts_sitting::Float64 = 11
    mean_number_of_contacts_standing::Float64 = 26

    # Sample the number of contacts for the ego individual
    num_of_contacts = if ego.occupation == 1
        rand(rng, Poisson(mean_number_of_contacts_sitting))
    elseif ego.occupation == 2
        rand(rng, Poisson(mean_number_of_contacts_standing))
    else
        0
    end

    resize!(indivs, num_of_contacts)

    # Initialize a vector to store the sampled contacts
    cnt = 0
    # Randomly select contacts from the same section
    while cnt < num_of_contacts
        contact = rand(rng, same_section_individuals)
        if contact != ego
            indivs[cnt + 1] = contact
            cnt += 1
        end
    end
end

## End of script
print("END CONTACT SAMPLING")