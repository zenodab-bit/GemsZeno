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
function sample_contacts_concert(concert_contacts::ConcertContacts,
    ego::Individual, present_individuals::Vector{Individual})
    
    #check if there are any individuals in the setting
    if isempty(present_individuals)
        throw(ArgumentError("No Individuals are present.
        Please provide a list of individuals."))
    end

    #if only ego is present, return an empty list
    if length(present_individuals) == 1
        return Individual[]
    end

    #determine the number of contacts for ego based on their "occupation", (i.e. sitting or standing)
    if ego.occupation == 1
        num_of_contacts = rand(concert_contacts.seDistribution)
    elseif ego.occupation == 2
        num_of_contacts = rand(concert_contacts.stDistribution)
    else 
        num_of_contacts = 0
    end

    #filter present_individuals to only include the one in the same "section" as ego
    same_section_individuals = filter(x -> x.occupation == ego.occupation && x != ego, present_individuals)

    #sample without replacement
    contacts = sample(same_section_individuals, num_of_contacts; replace = false)

    #return the list of sampled contacts
    return contacts
end
## === Convert rows to individuals ===
function row_to_individual(row)
    return Individual(
        id = row.id,
        sex = row.sex,
        age = row.age,
        occupation = row.occupation
        )
end

#filter the dataset to include only individuals attending the concert
attending_concert = newpeople[newpeople.occupation .!= -1, :]

#convert each row attending the concert to an individual object
all_individuals_list = [row_to_individual(row) for row in eachrow(attending_concert)]

## === Run ===

#
concert_method = ConcertContacts(
    mean_number_of_contacts_seated = 11,
    mean_number_of_contacts_standing = 26,
    distribution = "Poisson"
)

#dictionary to store contacts for each individual
all_contacts = Dict{Int, Vector{Individual}}()

#for each individual in the concert, sample their ontacts
for ego in all_individuals_list
    present_individuals = all_individuals_list

    #sample contacts for the current individual (ego)
    contacts = sample_contacts_concert(concert_method, ego, present_individuals)
    #println("Contacts for individual $(ego.id): $contacts")
    all_contacts[ego.id] = contacts
end

## end
print("END CONTACT SAMPLING")