## === Start ===
import GEMS: sample_contacts

# Define a custom struct for concert contact sampling,
# inheriting from ContactSamplingMethod in GEMS
mutable struct ConcertContacts <: GEMS.ContactSamplingMethod
end

# Function to sample contacts for a given individual at the concert
function GEMS.sample_contacts(
    concert_contacts::ConcertContacts,
    setting::GEMS.GlobalSetting,
    individual_index::Int64,
    present_individuals::Vector{Individual},
    tick::Int16;
    rng::AbstractRNG = Random.default_rng()
)
    # Get the ego individual (the individual for whom contacts are being sampled)
    ego = present_individuals[individual_index]

    # Skip if ego is not at the concert (occupation -1: not attending, 1: sitting, 2: standing)
    if ego.occupation != 1 && ego.occupation != 2
        return Individual[]  # Early return: no contacts for non-concert individuals
    end

    # Filter to include only individuals in the same section as ego (and exclude ego)
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)
    isempty(same_section_individuals) && return Individual[]

    # Define the mean number of contacts for sitting and standing individuals
    mean_number_of_contacts_sitting::Float64 = 11
    mean_number_of_contacts_standing::Float64 = 26

    # Sample the number of contacts for the ego individual based on their section
    num_of_contacts = if ego.occupation == 1
        rand(rng, Poisson(mean_number_of_contacts_sitting))  # Sitting section
    elseif ego.occupation == 2
        rand(rng, Poisson(mean_number_of_contacts_standing))  # Standing section
    else
        0  # Fallback (shouldn't happen due to early return)
    end

    # Initialize a vector to store the sampled contacts
    res = Vector{Individual}(undef, num_of_contacts)
    cnt = 0
    # Randomly select contacts from the same section
    while cnt < num_of_contacts
        contact = rand(rng, same_section_individuals)
        if contact != ego
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end

## End of script
print("END CONTACT SAMPLING")