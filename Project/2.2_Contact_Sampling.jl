## === Start ===
import GEMS: sample_contacts
#define a custom struct for concert contact sampling,
    #inheriting from ContactSamplingMethod in GEMS
mutable struct ConcertContacts <: GEMS.ContactSamplingMethod

end


#function to sample contacts for a given individual at the concert
function GEMS.sample_contacts(
    concert_contacts::ConcertContacts,
    setting::GEMS.GlobalSetting,
    individual_index::Int64,
    present_individuals::Vector{Individual},
    tick::Int16;
    rng::AbstractRNG = Random.default_rng()
)
    # Get the ego individual
    ego = present_individuals[individual_index]

    # Skip if ego is not at the concert (e.g., occupation is -1 or invalid)
    if ego.occupation != 1 && ego.occupation != 2
        return Individual[]  # Early return: no contacts for non-concert individuals
    end

    # Filter to include only individuals in the same section as ego (and exclude ego)
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)
    isempty(same_section_individuals) && return Individual[]

    # Rest of your logic (unchanged)
    mean_number_of_contacts_seated::Float64 = 11
    mean_number_of_contacts_standing::Float64 = 26

    num_of_contacts = if ego.occupation == 1
        rand(rng, Poisson(mean_number_of_contacts_seated))
    elseif ego.occupation == 2
        rand(rng, Poisson(mean_number_of_contacts_standing))
    else
        0  # Fallback (shouldn't happen due to early return)
    end

    res = Vector{Individual}(undef, num_of_contacts)
    cnt = 0
    while cnt < num_of_contacts
        contact = rand(rng, same_section_individuals)
        if contact != ego
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end

## end
print("END CONTACT SAMPLING")