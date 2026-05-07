# Sum the daily_cases for GlobalSetting ('g')
global_cases = filter(row -> row.setting_type == 'g', rd_concert.data["dataframes"]["tick_cases_per_setting"])
total_global_infected = sum(global_cases.daily_cases)
println("Total infected in GlobalSetting: ", total_global_infected)