The idea behind this code is to integrate the GEMS code to be able to have events
    where people can get extra infections and contacts.
It is important to notice that the contacts happening at the events are properly extra contacts.
    GEMS calculates normally the number of contacts an individual has in the normal settings,
    without considering their participation in events. So the event contacts are added on top
    of all the other contacts.
To do so the code is using the global setting.
    The global setting contains the entire population, so for large population is very slow.
    Various precautions have been taken to have it run efficiently, but it has not been tested on larger population.
GEMS's pathogen model has no reinfection or waning-immunity pathway — once someone is
    infected, exposed, infectious, recovered, or dead, they stay in that trajectory. This
    is relied on by the code that classifies attendees into compartments (7_Validation).


The code is divided in 8 +1 files:
0_Helpers
    This file contains a series of struct and function that get called by the other files.
1_UserConfig
    This file is were the user can define transmission and superspreader probability.
        Here is where the user can define events.
2_Interface
    This is the file that links all together by calling the other files and running the simulations.
3_Population
    This is the file that creates the different events and assign the population to participate.
4_Contacts
    This file contains the contact function for the whole simulation, not just events:
        the normal settings (household, office, etc.) and the events each use their own logic here.
5_Transmission
    This file contains the transmission function for the whole simulation, same as above:
        normal settings and events each have their own logic here.
6_Analysis
    This file contains all the output related functions.
    Plots and metrics are produced here.
7_Validation
    This file is contains a series of checks and extra metrics to help check the correct
        functioning of the code.
config_concert_covid
    This file is the classic TOML for GEMS simulations.
        NOTE: general_rate and contactparameter in this file are required to exist by GEMS but
            are never actually read — they have no effect. The real values are set in 1_UserConfig.



The code is run from file 2_Interface.
It first call file 0_Helpers, that contains a series of useful struct and functions.
Then it moves to file 1_UserConfig.
    In this file the User can decide transmission probability for the normal individual and for the superspreaders, together with the probability of superspreaders.
    The User can then creates categories of events. The fiels in category are:
        id: Unique id used for internal processing. MUST BE UNIQUE otherwise events may be
            overwritten.
        name: Make it easier for the user to understand the outputs.
            Should also be unique — some output filenames are built from it, and a collision
                overwrites one category's output with another's.
        date_range: In which dates can events of this category happen.
            NOTE: Events of the same category cannot happen on the same day. The code will
                check and try to pick different dates but it needs to have enough options.
            NOTE: Different categories CAN land on the same date by coincidence. If that happens
                and it creates a conflict (someone eligible for both), whichever category's event
                gets processed first that day wins the person; the other backfills from its random
                pool instead. Left as an accepted edge case rather than fixed.
        sections: Each category must have at least 1 declared section. Here is were the size and
            number of contacts are declared.
            There can be multiple sections, they must have unique ids.
                If there are multiple sections, every event of that category will have all the sections.
        n_draws: how many times this category recurs. Note the total number of events created
            is n_draws times the number of sections, not n_draws itself.
        min and max age: selfexplanatory, minimum and maximum age for someone attending the event.
            NOTE: age_boundaries (below) are shared across categories, but since min/max age
                truncate who's eligible first, the same boundary can cover a different real age
                range per category.
        age_weights: the age distribution of the participants to events of this type. This is
            capped by the above min and max ages.
            Age weights dont have to sum up to 1, they are proper weights. As such, the true
                distribution of age at the event may be slightly different.
        sex weights: the sex distribution of the participants to events of this type.
            Sex weights dont have to sum up to 1, they are proper weights. As such, the true
                distribution of sex at the event may be slightly different.
        core: this represent what percentage is attending every single event.
            It is calculated on the smallest event of that category that has been generated, to
                guarantee that all the members are always attending.
            The regular part follows the demographic distributions; the superspreader part
                (below) is picked uniformly at random instead, not demographically weighted.
        loyalty: this represent what percentage of the remaining non-core spots are reserved for
            people that already attended at least one non-core event of that category, core excluded.
            This pool only grows and never expires. Selection follows the demographic weights too;
                attending more times before doesn't give extra weight.
        min_superspreaders: As is our interest to check the worst cases, it is possible to pick
            how many superspreader minimum have to attend. Extras could be picked at random later.
        cross_section_mean_contacts: How many contacts a person in one section can have with a
            person in another section.
            NOTE_1: This is the same value distributed across all sections.
            NOTE_2: This are added on top of the contacts intra section and can still contact
                in the same section.

        NOTE: Superspreaders and core are picked ONCE per category, before any of its events are
            processed — not "for the first event" specially. The same core then attends every
            event of that category from the first one on, minus same-day conflicts.
            For each event, the order is: core first, then loyalty (demographic weights), then
                random fill (demographic weights) for whatever's left. Anyone filled by loyalty
                OR by random fill becomes loyalty-eligible for that category's later events.

    Then the user as to configure the events by specifing which cateogries are included in
        the simulation. This allows to have multiple events and easily exclude or include some
        for testing instead.
        event_config contains age boundaries that are used to categorize age in the same way for all events,
        age and sex dist are there as a generalization. If a category doesnt have age and sex weights, these values will be used instead.

Then the code moves to file 3_Population.
    This file turns the categories from 1_UserConfig into actual events (assigning each
        a real date and size), builds the population individuals will be assigned from,
        and then assigns people to every event following the rules described above
        (core, loyalty, random fill, demographic weighting).
    Nothing here needs to be configured by the user — this is what happens automatically
        once 1_UserConfig is set up.

    Transmission probability is assigned once per person, at the very start, before any
        events are even sampled. Each person gets a fixed value drawn from the transmission
        and superspreader probabilities set in 1_UserConfig, based on whether they happen to
        be a superspreader. This value never changes afterward, regardless of which events
        (if any) that person later attends.

    A few custom fields get added to every person at this point, which are what let the
        rest of the code (contacts, transmission, validation) know who attended what:
        category_ids, draw_ids, section_ids: which category/draw/section they attended,
            one entry per event attended.
        event_dates: the date of each event attended.
        mean_event_contacts / std_event_contacts: their within-section contact rate at
            each event attended.
        cross_section_mean_contacts / cross_section_std_contacts: same, but for contacts
            with people in other sections of the same event.
        is_superspreader / transmission_prob: fixed at the start, as above, not tied to
            any specific event.

Then the code moves to file 4_Contacts.
    This file defines how many contacts a person has in every setting, both normal ones
        (household, office, etc.) and events. For events, it handles both the within-section
        and cross-section contacts described above.
    Nothing here needs to be configured by the user.

Then the code moves to file 5_Transmission.
    This file defines whether a contact actually results in an infection. For normal settings
        it simply uses the infecter's own transmission_prob (fixed in 3_Population). For events,
        it also checks that the infecter and infected attended the same event (any section).
    Nothing here needs to be configured by the user.

With 0_Helpers, 1_UserConfig, 3_Population, 4_Contacts and 5_Transmission all loaded, control
    returns to 2_Interface, which samples the events, prepares and assigns the population, then
    builds and runs the actual GEMS simulation using everything defined above.

Once the simulation finishes, the code moves to file 6_Analysis.
    This runs automatically and produces the text metrics and every plot (epidemic curves,
        cases by setting, per-event SEIR bars, infected boxplot), saved to the Results folder.
    Nothing here needs to be configured by the user.

If run_validation is set to true (in 2_Interface), the code then moves to file 7_Validation.
    This also runs automatically, and checks the simulation's actual outcomes (assignment
        counts, compartment totals, demographics, epidemic state) against what's expected,
        to help confirm everything is working correctly.
    Not required for a normal run, but useful to catch mistakes.
