# === User Parameters ===

# Simulation
rng = Xoshiro()


# Transmission
general_rate = 0.3
std_rate = 0.1

# Superspreaders
superspreader_prob = 0.10
superspreader_rate = 0.8
superspreader_std = 0.15

# Event definitions
category_1 = Category(
    id = 1,
    name = "festival",
    date_range = (40, 60),
    sections = [
        Section(id=1, name="seated", n_range=(300,500), mean_contacts=4.0, std_contacts=6.0),
        Section(id=2, name="standing", n_range=(800,1000), mean_contacts=12.0, std_contacts=18.0)
    ],
    n_draws = 2,
    min_age = 18,
    max_age = 999,
    age_weights = [0.5, 0.35, 0.15],
    sex_weights = [0.6, 0.4],
    core = 0.0,
    loyalty = 0.0,
    min_superspreaders = 0
    

)

category_2 = Category(
    id = 2,
    name = "sport",
    date_range = (10, 40),
    sections = [
        Section(id=1, name="", n_range=(300,400), mean_contacts=8.0, std_contacts=12.0)
    ],
    n_draws = 5,
    min_age = 16,
    max_age = 999,
    age_weights = [0.45, 0.40, 0.15],
    sex_weights = [0.55, 0.45],
    core = 0.1,
    loyalty = 2,
    min_superspreaders = 1
)

event_config = EventConfig(
    categories = [category_1, category_2],
    transmission_rate = general_rate,
    age_boundaries = [45, 65],
    age_dist = [0.211, 0.347, 0.442],
    sex_dist = [[0.420, 0.580], [0.395, 0.605], [0.426, 0.574]]
) 