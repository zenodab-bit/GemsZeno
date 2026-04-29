## === Start ===

@with_kw struct ConcertContacts <: ContactSamplingMethod
    distribution::String = "Poisson"
    mean_number_of_contacts_seated::Float64
    mean_number_of_contacts_standing::Float64

    seDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_seated)
    stDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_standing)
end

function sample_contacts_concert(concert_contacts::ConcertContacts,
    ego::Individual, present_individuals::Vector{Individual})
    rand(concert_contacts.seDistribution)
    
    #check if there are any individuals in the setting
    if isempty(present_individuals)
        throw(ArgumentError("No Individuals are present.
        Please provide a list of individuals."))
    end

    #if only ego is present, return an empty list
    if length(present_individuals) == 1
        return Individual[]
    end

    #set the number of contacts for ego to 0
    num_of_contacts = 0

    #determine the number of contacts for ego based on their "occupation"
    num_of_contacts = ego.occupation == 1 ?
        rand(concert_contacts.seDistribution) :
        rand(concert_contacts.stDistribution)

    #initialiye the result vectors
    res = Vector{Individual}(undef, num_of_contacts)
    cnt = 0

    #sample contacts from present_individuals, excluding ego
    while cnt < num_of_contacts
        contact = rand(present_individuals)
        if contact!=ego
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end

attending_concert = newpeople[newpeople.occupation .! = -1, :]
all_individuals_list = [row_to_individual(row) for row in eachrow(attending_concert)]

## === Run ===
concert_method = ConcertContacts(
    mean_number_of_contacts_seated = 11,
    mean_number_of_contacts_standing = 26,
    distribution = "Poisson"
)

all_contacts = Dict{Int, Vector{Individual}}()

for ego in all_individuals_list
    present_individuals = all_individuals_list

    contacts = sample_contacts_concert(concert_method, ego, present_individuals)
    println("Contacts for individual $(ego.id): $contacts")
    all_contacts[ego.id] = contacts
end

## end
print("END CONTACT SAMPLING")