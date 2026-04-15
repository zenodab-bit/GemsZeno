## First
using GEMS, DataFrames
pop_df = DataFrame(
    id = collect(1:100_000),
    age = rand(1:100, 100_000),
    sex = rand(1:2, 100_000),
    household = append!(collect(1:50_000), collect(1:50_000))
)
my_pop = Population(pop_df)
sim = Simulation(population = my_pop)

using Plots
hh_sizes = size.(households(sim))
histogram(hh_sizes, xlims = (0, 10))

## Adjusting population

function  sample_vaccs!(i)
    if age(i) >= 18 && rand(1:100) < age(i)
        i.number_of_vaccinations = 1
    end
end

each!(sample_vaccs!, my_pop)

inds = individuals(my_pop)
df = DataFrame(age = age.(inds), vaccinations = number_of_vaccinations.(inds))
df_grouped = groupby(df, :age)
df_combined = combine(df_grouped, :vaccinations => (v -> sum(v) / length(v)) => :vacc_fraction)
plot(df_combined.age, df_combined.vacc_fraction,
    xlabel = "Age",
    ylabel = "Vaccination Coverage",
    legend = false)