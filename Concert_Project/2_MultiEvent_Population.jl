function age_group_label(age, age_boundaries)
    for i in eachindex(age_boundaries)
        if age <= age_boundaries[i]
            return "<=$(age_boundaries[i])"
        end
    end
    return ">$(age_boundaries[end])"
end

function prepare_population(event_config::EventConfig)
    people = JLD2.load(joinpath(@__DIR__, "Datastorage", "people_Saalekreis.jld2"))["data"]
    
    age_boundaries = event_config.age_boundaries
    age_groups = [i == length(age_boundaries) + 1 ? ">$(age_boundaries[end])" : "<=$(age_boundaries[i])" for i in 1:length(age_boundaries)+1]
    sex_levels = [1, 2]

    people.age_group = age_group_label.(people.age, Ref(age_boundaries))
    people.age_group = categorical(people.age_group; ordered=true, levels=age_groups)

    people.event_id = fill(-1, nrow(people))
    people.section_id = fill(-1, nrow(people))
    people.mean_event_contacts = fill(0.0, nrow(people))

    return people, age_groups, sex_levels
end  

 
### Functions ###
function assign_events!(people, event_config, age_groups, sex_levels, rng)
    
    
    for event in event_config.events
        for section in event.sections
               for (j, age) in enumerate(age_groups)
                    for (k, sex) in enumerate(sex_levels)
                        candidates = findall(
                            (people.age_group .== age) .&
                            (people.sex .== sex) .&
                            (people.event_id .== -1)
                        )
                        n = round(Int, section.n * section.age_dist[j] * section.sex_dist[j][k])
                        selected = sample(rng, candidates, n, replace=false)

                        people.event_id[selected] .= event.id
                        people.section_id[selected] .= parse(Int32, split(section.id, "_")[2])
                        people.mean_event_contacts[selected] .= section.mean_contacts
                        people.event_date[selected] .= event.date
                    end
                end
        end
    end
end


### Validation ###
function validate_assignment(people::DataFrame, event_config::EventConfig)
    println("\n=== Assignment Validation ===")
    
    # overall counts
    println("\nPeople per event_id:")
    println(countmap(people.event_id))

    # check each event and section
    for event in event_config.events
        println("\nEvent $(event.id) (date=$(event.date)):")
        for section in event.sections
            assigned = sum(
                (people.event_id .== event.id) .&
                (people.section_id .== parse(Int32, split(section.id, "_")[2]))
            )
            expected = section.n
            status = assigned ≈ expected ? "✓" : "✗ expected $expected"
            println("  Section $(section.id): $assigned assigned $status")
        end
    end

    # total unassigned
    unassigned = sum(people.event_id .== -1)
    println("\nUnassigned: $unassigned / $(nrow(people))")
end
