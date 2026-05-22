## === Define Custom Contact Sampling Method ===

# Import required functions and types
import GEMS: sample_contacts!
using Random: Xoshiro

# Define a custom contact sampling method for concert settings
# Inherits from GEMS.ContactSamplingMethod to override default behavior
mutable struct ConcertContacts <: GEMS.ContactSamplingMethod
end




## === Implement Contact Sampling Logic ===

# Override the default contact sampling function for concert settings
# Generates contacts for an individual in the GlobalSetting (concert)
function GEMS.sample_contacts!(
    indivs::Vector{Individual},          # Output vector for sampled contacts
    concert_contacts::ConcertContacts,  # Custom contact sampling method
    setting::GEMS.GlobalSetting,         # Must be GlobalSetting for concerts
    individual_index::Int,              # Index of current individual
    present_individuals::Vector{Individual},  # All individuals in the setting
    tick::Int16,                         # Current simulation time step
    replace::Bool,                       # Sample with replacement flag
    rng::Xoshiro                          # Random number generator
)
    # Clear the output vector
    empty!(indivs)

    # Get the current individual (ego)
    ego = present_individuals[individual_index]

    # Skip if ego is not attending the concert
    if ego.occupation != 1 && ego.occupation != 2
        return Individual[]
    end

    # Filter to include only individuals in the same concert section as ego
    # Exclude ego to avoid self-contacts
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)
    isempty(same_section_individuals) && return Individual[]

    # Sample number of contacts based on concert section
    num_of_contacts = if ego.occupation == 1
        rand(rng, Poisson(mean_number_of_contacts_sitting))
    elseif ego.occupation == 2
        rand(rng, Poisson(mean_number_of_contacts_standing))
    else
        0  # Fallback
    end

    # Pre-allocate space for efficiency
    resize!(indivs, num_of_contacts)

    # Randomly select contacts from the same section
    cnt = 0
    while cnt < num_of_contacts
        contact = rand(rng, same_section_individuals)
        if contact != ego
            indivs[cnt + 1] = contact
            cnt += 1
        end
    end
end

## End of script
println("END CONTACT SAMPLING")