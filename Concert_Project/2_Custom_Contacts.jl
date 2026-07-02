## === Define Custom Contact Sampling Method ===

# Import required functions and types
import GEMS: sample_contacts!
using Random: Xoshiro, shuffle

# Define a custom contact sampling method for concert settings
# Inherits from GEMS.ContactSamplingMethod to override default behavior
@with_kw mutable struct ConcertContacts <: GEMS.ContactSamplingMethod
    contactparameter::Float64 = 0.0
end

## === Calculate the values needed for binomial distribution ===
    function negbin_params(mean, std)
    variance = std^2
    p = mean / variance
    r = mean^2 / (variance - mean)
    return r, p
end

r_sit, p_sit = negbin_params(mean_number_of_contacts_sitting, std_number_of_contacts_sitting)
r_sta, p_sta = negbin_params(mean_number_of_contacts_standing, std_number_of_contacts_standing)



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
    same_section_individuals = Vector{Individual}()
    for x in present_individuals
        if occupation(x) == occupation(ego) && x != ego
            push!(same_section_individuals, x)
        end
    end
    isempty(same_section_individuals) && return Individual[]

    # Sample number of contacts based on concert section
    num_of_contacts = min(
    if ego.occupation == 1
        rand(rng, NegativeBinomial(r_sit, p_sit))
    elseif ego.occupation == 2
        rand(rng, NegativeBinomial(r_sta, p_sta))
    else
        0
    end,
    length(same_section_individuals)
)

    # Pre-allocate space for efficiency
    resize!(indivs, num_of_contacts)

    # Randomly select contacts from the same section
    shuffled = shuffle(rng, same_section_individuals)
    for cnt in 1:num_of_contacts
        indivs[cnt] = shuffled[cnt]
    end
end

## END
println("\nEND CUSTOM CONTACTS 2")