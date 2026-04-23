## === Start ===

@with_kw struct ConcertContacts <: ContactSamplingMethod
    distribution::String = "Poisson"
    mean_number_of_contacts_seated::Float64
    mean_number_of_contacts_standing::Float64

    seDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_seated)
    stDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_standing)
end

function GEMS.sample_contacts(concert_contacts::ConcertContacts,
    setting::Setting, ego::Individual, present_individuals::Vector{Individual}, tick::Int16)

    if isempty(present_individuals)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_individuals) == 1
        return Individual[]
    end

    num_of_contacts = 0

    
    
end

attending_concert = newpeople[newpeople.concert_attendance .!= "Not attending", :]
all_individuals_list = [row_to_individual(row) for row in eachrow(attending_concert)]

concert_attendance_dict = Dict{Int, String}()
for row in eachrow(newpeople)
    concert_attendance_dict[row.id] = row.concert_attendance
end

## === Run ===
concert_method = ConcertContacts(
    mean_number_of_contacts_seated = 11,
    mean_number_of_contacts_standing = 26,
    distribution = "Poisson"
)

all_contacts = Dict{Int, Vector{Individual}}()

for ego in all_individuals_list
    present_individuals = all_individuals_list

    contacts = sample_contacts_concert(concert_method, ego, present_individuals, concert_attendance_dict)
    println("Contacts for individual $(ego.id): $contacts")
    all_contacts[ego.id] = contacts
end