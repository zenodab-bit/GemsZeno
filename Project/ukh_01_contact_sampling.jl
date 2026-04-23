######################################## Contacts Sampling ############################################

@with_kw struct FixedContacts <: ContactSamplingMethod
    distribution::String = "Poisson"
    mean_number_of_contacts_weekday::Float64
    mean_number_of_contacts_weekend::Float64
    wdDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_weekday...)
    weDistribution::Distribution = eval(Meta.parse(distribution))(mean_number_of_contacts_weekend...)
    # the fact, that the contacts differ between weekdays and weekend will be implement in the `sample_contacts()` function 
end

#=
create an "override" (type in "function GEMS.sample_contacts() ... end") of the "sample_contacts()" function. This function will contain your specific sampling logic and take your created struct as an input.
it's important to note, that every custom "sample_contacts()" function needs the argumetns of type (::ContactSamplingMethod, ::Setting, ::Individual, ::Vector{Individual}, ::Int16) (the ::Int16 is the current "tick" of the simulation. When using the "contact_samples()" method, this defaults to "0") so that the simulation can automatically use the new function!

Now we define the beforementioned "sample_contacts()" function. This function incorporates the "sampling logic" for our struct "FixedContacts". Here we want to sample contacts based on the current tick and a pre-defined number of contacts. To connect the "ticks" of the Simulation to a "real world calender" we define "tick 0" as a monday.
Following this a "weekend" would occur every 6 and 7 ticks (0 = Mon, 1 = Tue, ... , 5 = Sat, 6 = Sun). We can use this information to create a function that checks, whether a tick is a "weekday" or "weekend" by taking the modulo of 7 of the tick.
=#

"""

# Parameters:
- `fixed_contacts` = your own struct
- `setting` = setting of the `ego`
- `ego` = Individual, for which the contacts should be sampled
- `present_individuals` = Individuals, currently present in `setting` 
- `tick` = current tick of the simulation object
"""
function GEMS.sample_contacts(fixed_contacts::FixedContacts, setting::Setting, ego::Individual, present_individuals::Vector{Individual},tick::Int16)
    rand(fixed_contacts.wdDistribution)
    # get the parameters stored in the "FixedContacts" struct
    # contacts_weekday::Int64 = rand(fixed_contacts.wdDistribution)
    # contacts_weekend::Int64 = rand(fixed_contacts.weDistribution)
    # contacts_friday::Int64 = rand(fixed_contacts.fDistribution)

    if isempty(present_individuals)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_individuals) == 1
        return Individual[]
    end

    num_of_contacts = 0

    if (tick % 7) == 5 || (tick % 7) == 6
        num_of_contacts = rand(fixed_contacts.weDistribution)
    # elseif (tick % 7) == 4 #friday
    #     num_of_contacts = rand(fixed_contacts.fDistribution)
    else
        num_of_contacts = rand(fixed_contacts.wdDistribution)
    end

    res = Vector{Individual}(undef, num_of_contacts)

    cnt = 0
    # Draw until contact list is filled, skip whenever the index individual was selected
    while cnt < num_of_contacts
        contact = rand(present_individuals)
        # if contact is NOT index individual, add them to contact list
        if Ref(contact) .!== Ref(ego)
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end

#=
For our second struct we define "HouseholdSizeBasedContactSampling". This ContactSamplingMethod will sample contacts based on the size of the Household (the greater the Household size, the more contacts will be sampled). Since we can infer the Household size directly in the Simulation, we don't need to define any parameters here.
=#
struct HouseholdSizeBasedContactSampling <: ContactSamplingMethod
    # no params needed, the actual Household size will be inferred from the "Household" Setting in the Simulation.
end

#=
Now we have to define a second implementation of "sample_contacts()". Please note, that the first parameter has changed. The structs we defined here will be used to help the Julia Compiler to infer which implementation of "sample_contacts()" should be used.
To achieve "HouseholdSizeBasedContactSampling", we just need to fetch the current size of the individuals vector stored in the setting passed to this function. The parameter "setting" contains the setting of the individual, for which we perform the contact sampling.
=#
"""

# Parameters:
- `hh_size_based_sampling` = your own struct
- `setting` = setting of the `ego`
- `ego` = Individual, for which the contacts should be sampled
- `present_individuals` = Individuals, currently present in `setting` 
- `tick` = current tick of the simulation object
"""
function GEMS.sample_contacts(hh_size_based_sampling::HouseholdSizeBasedContactSampling, setting::Setting, ego::Individual, present_individuals::Vector{Individual}, tick::Int16)

    if isempty(present_individuals)
        throw(ArgumentError("No Individual is present in $setting. Please provide a Setting, where at least 1 Individual is present!"))
    end

    if length(present_individuals) == 1
        return Individual[]
    end

    num_of_contacts = size(setting) - 1
    res = Vector{Individual}(undef, num_of_contacts)
    cnt = 0
    # Draw until contact list is filled, skip whenever the index individual was selected
    while cnt < num_of_contacts
        contact = rand(present_individuals)
        # if contact is NOT index individual, add them to contact list
        if Ref(contact) .!== Ref(ego)
            res[cnt + 1] = contact
            cnt += 1
        end
    end

    return res
end

