using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Random

include(srcdir("sir_model.jl"))

function run_experiment(p)
    beta = p[:beta]  # Создаём β_und и β_det на основе скалярного beta
    β_und = fill(beta, 3)
    β_det = fill(beta/10, 3)
    model = initialize_sir(;   # Передаём в модель
                           Ns = p[:Ns],
                           β_und = β_und,
                           β_det = β_det,
                           infection_period = p[:infection_period],
                           detection_time = p[:detection_time],
                           death_rate = p[:death_rate],
                           reinfection_probability = p[:reinfection_probability],
                           Is = p[:Is],
                           seed = p[:seed],
                           n_steps = p[:n_steps],  # этот параметр не используется в initialize_sir, но может быть нужен для цикла
                           )

    infected_fraction(model) =
        count(a.status == :I for a in allagents(model)) / nagents(model)
            peak_infected = 0.0

            for step = 1:p[:n_steps]

                agent_ids = collect(allids(model))   # Ручной шаг (безопасный)
                for id in agent_ids
                    agent = try
                        model[id]
                    catch
                        nothing
                    end
                    if agent !== nothing
                        sir_agent_step!(agent, model)
                    end
                end

                frac = infected_fraction(model)
                if frac > peak_infected
                    peak_infected = frac
                end
            end

            final_infected = infected_fraction(model)
            final_recovered = count(a.status == :R for a in allagents(model)) / nagents(model)
                total_deaths = sum(p[:Ns]) - nagents(model)

                return (
                    peak = peak_infected,
                    final_inf = final_infected,
                    final_rec = final_recovered,
                    deaths = total_deaths,
                    )
            end


            beta_range = 0.1:0.1:1.0    # Диапазон значений beta (скаляр)
            seeds = [42, 43, 44]


            params_list = []  # Создаём список параметров
            for b in beta_range
                for s in seeds
                    push!(
                        params_list,
                        Dict(
                            :beta => b,  # скалярное значение
                            :Ns => [1000, 1000, 1000],
                            :infection_period => 14,
                            :detection_time => 7,
                            :death_rate => 0.02,
                            :reinfection_probability => 0.1,
                            :Is => [0, 0, 1],
                            :seed => s,
                            :n_steps => 100,
                            ),
                        )
                end
            end


            results = []     # Запуск экспериментов
            for params in params_list
                data = run_experiment(params)
                push!(results, merge(params, Dict(pairs(data))))
                println("Завершён эксперимент с beta = $(params[:beta]), seed = $(params[:seed])")
            end

            df = DataFrame(results)
            CSV.write(datadir("beta_scan_all.csv"), df)

            using Statistics
            grouped = combine(
                groupby(df, [:beta]),
                :peak => mean => :mean_peak,
                :final_inf => mean => :mean_final_inf,
                :deaths => mean => :mean_deaths,
                )

            plot(
                grouped.beta,
                grouped.mean_peak,
                label = "Пик эпидемии",
                xlabel = "Коэффициент заразности β",
                ylabel = "Доля инфицированных",
                marker = :circle,
                linewidth = 2,
                )
            plot!(
                grouped.beta,
                grouped.mean_final_inf,
                label = "Конечная доля инфицированных",
                marker = :square,
                )
            plot!(grouped.beta, grouped.mean_deaths ./ 3000, label = "Доля умерших", marker = :diamond)
            savefig(plotsdir("beta_scan.png"))

            println("Результаты сохранены в data/beta_scan_all.csv и plots/beta_scan.png")
