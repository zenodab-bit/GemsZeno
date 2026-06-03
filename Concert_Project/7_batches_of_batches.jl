## === Global Configuration ===
# --- Concert Settings ---
# Note: concert_date is not const here as it changes each batch
concert_date = 1

const event_size_total = 1000
const concert_groups_percentage = [1, 0]
const concert_groups_number = [583, 576]
const concert_attendance_levels = [1, 2]
const concert_groups_number_true = true

# --- Demographic Settings ---
const sex_groups_percentage = [0.5, 0.5]
const sex_levels = [1, 2]
const age_groups_percentage = [
    0.125,  # Under 18
    0.125,  # 18-25
    0.125,  # 26-30
    0.125,  # 31-35
    0.125,  # 36-40
    0.125,  # 41-45
    0.125,  # 46-50
    0.125   # 50 and over
]
const age_groups = ["<18", "18-25", "26-30", "31-35", "36-40", "41-45", "46-50", "50+"]

# --- Contact Settings ---
const mean_number_of_contacts_sitting  = 4
const mean_number_of_contacts_standing = 12

# --- Batch of Batches Settings ---
const n_simulations      = 100
const concert_days_range = 1:100




## === Derived Constants ===
const actual_event_size = concert_groups_number_true ? sum(concert_groups_number) : event_size_total




## === Include Custom Modules ===
include("1_Custom_Population.jl")
include("2_Custom_Contacts.jl")
include("3_Custom_Transmission.jl")
include("4_Custom_Logger_ResultData.jl")




## === Storage ===
infected_distributions = Dict{Int, Vector{Float64}}()
summary_by_day         = Dict{Int, NamedTuple}()

for day in concert_days_range
    infected_distributions[day] = Float64[]
end




## === Run Batch of Batches ===
for day in concert_days_range
    println("\n=== Concert day $day of $(last(concert_days_range)) ===")

    global concert_date = day
    infected_at_concert_v = Float64[]

    for i in 1:n_simulations
        sim = Simulation(
            configfile   = "Concert_Project/toml/config_concert_covid.toml",
            population   = "Concert_Project/Datastorage/people_Saalekreis_concert.jld2",
            settingsfile = "Concert_Project/Datastorage/settings_Saalekreis.jld2",
            global_setting_contacts = ConcertContacts(),
            label = "Concert simulation day $day run $i"
        )

        cl = CustomLogger(concert_day_stats = concert_infectious)
        customlogger!(sim, cl)
        run!(sim)

        # count infected at concert from infection logger
        inf_logger         = dataframe(infectionlogger(sim))
        global_cases_count = 0
        for row in eachrow(inf_logger)
            if row.tick == concert_date && row.setting_type == 'g'
                global_cases_count += 1
            end
        end
        push!(infected_at_concert_v, global_cases_count)
    end

    # store distribution and summary for this day
    infected_distributions[day] = infected_at_concert_v
    summary_by_day[day] = (
        mean   = mean(infected_at_concert_v),
        std    = std(infected_at_concert_v),
        cv     = std(infected_at_concert_v) / max(mean(infected_at_concert_v), 1) * 100,
        min    = minimum(infected_at_concert_v),
        p25    = quantile(infected_at_concert_v, 0.25),
        median = median(infected_at_concert_v),
        p75    = quantile(infected_at_concert_v, 0.75),
        p90    = quantile(infected_at_concert_v, 0.90),
        p95    = quantile(infected_at_concert_v, 0.95),
        max    = maximum(infected_at_concert_v)
    )

    println("  Mean infected at concert: $(round(mean(infected_at_concert_v), digits=1))  Std: $(round(std(infected_at_concert_v), digits=1))")
end




## === Print Summary Table ===
println("\n=== Summary by Concert Day ===")
println(rpad("Day", 5), " | ",
        rpad("Mean", 8), " | ",
        rpad("Std", 8), " | ",
        rpad("CV%", 8), " | ",
        rpad("Min", 6), " | ",
        rpad("P25", 6), " | ",
        rpad("Median", 8), " | ",
        rpad("P75", 6), " | ",
        rpad("P90", 6), " | ",
        rpad("P95", 6), " | ",
        "Max")
println("-"^95)
for day in concert_days_range
    s = summary_by_day[day]
    println(rpad(day, 5), " | ",
            rpad(round(s.mean,   digits=1), 8), " | ",
            rpad(round(s.std,    digits=1), 8), " | ",
            rpad(round(s.cv,     digits=1), 8), " | ",
            rpad(round(s.min,    digits=1), 6), " | ",
            rpad(round(s.p25,    digits=1), 6), " | ",
            rpad(round(s.median, digits=1), 8), " | ",
            rpad(round(s.p75,    digits=1), 6), " | ",
            rpad(round(s.p90,    digits=1), 6), " | ",
            rpad(round(s.p95,    digits=1), 6), " | ",
            round(s.max, digits=1))
end




## === Plot: Boxplot of infected at concert by day ===
days = collect(concert_days_range)
data = [infected_distributions[day] for day in days]

gp = boxplot(
    repeat(days, inner = n_simulations),
    vcat(data...),
    title     = "Distribution of Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Infections at Concert",
    legend    = false,
    dpi       = 300,
    color     = :blue,
    fillalpha = 0.5,
    linewidth = 1
)
png(gp, "Concert_Project/Plots/Batch_of_batches_boxplot.png")






## === Plot: Boxplot of infected at concert by day ===
days = collect(concert_days_range)
data = [infected_distributions[day] for day in days]

gp = boxplot(
    repeat(days, inner = n_simulations),
    vcat(data...),
    title     = "Distribution of Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Infections at Concert",
    legend    = false,
    dpi       = 300,
    color     = :blue,
    fillalpha = 0.5,
    linewidth = 1
)
png(gp, "Concert_Project/Plots/Batch_of_batches_boxplot.png")






## === Plot: Mean infected at concert by day ===
gp2 = plot(days,
    [summary_by_day[day].mean for day in days],
    ribbon    = [summary_by_day[day].std for day in days],
    fillalpha = 0.3,
    title     = "Mean Infections at Concert by Day",
    xlabel    = "Concert Day",
    ylabel    = "Mean Infections at Concert",
    label     = "Mean ± Std",
    color     = :blue,
    linewidth = 2,
    dpi       = 300
)
png(gp2, "Concert_Project/Plots/Batch_of_batches_mean.png")




## END
println("\nEND SIMULATION 7 BATCH OF BATCHES")