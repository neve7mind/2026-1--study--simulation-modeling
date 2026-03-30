using DrWatson
@quickactivate "project"

using BlackBoxOptim, Random, Statistics

include(srcdir("sir_model.jl"))

function cost_multi(x)

    model = initialize_sir(; # x[1]: β_und, x[2]: death_rate, x[3]: detection_time
                           Ns = [1000, 1000, 1000],
                           β_und = fill(x[1], 3),
                           β_det = fill(x[1]/10, 3),
                           infection_period = 14,
                           detection_time = round(Int, x[2]),
                           death_rate = x[3],
                           reinfection_probability = 0.1,
                           Is = [0, 0, 1],
                           seed = 42,
                           n_steps = 100,
                           )

    infected_frac(model) = count(a.status == :I for a in allagents(model)) / nagents(model)
        dead_count(model) = 3000 - nagents(model)

        peak_infected = 0.0


        replicates = 5 # Запускаем с несколькими повторами
        peak_vals = Float64[]
        dead_vals = Int[]

        for rep = 1:replicates
            model = initialize_sir(;
                                   Ns = [1000, 1000, 1000],
                                   β_und = fill(x[1], 3),
                                   β_det = fill(x[1]/10, 3),
                                   infection_period = 14,
                                   detection_time = round(Int, x[2]),
                                   death_rate = x[3],
                                   reinfection_probability = 0.1,
                                   Is = [0, 0, 1],
                                   seed = 42 + rep,
                                   n_steps = 100,
                                   )

            for step = 1:100
                Agents.step!(model, 1)
                frac = infected_frac(model)
                if frac > peak_infected
                    peak_infected = frac
                end
            end

            push!(peak_vals, peak_infected)
            push!(dead_vals, dead_count(model))
        end

        return (mean(peak_vals), mean(dead_vals) / 3000)  # доля умерших
    end

    result = bboptimize(
        cost_multi,
        Method = :borg_moea,
        FitnessScheme = ParetoFitnessScheme{2}(is_minimizing = true),
        SearchRange = [
            (0.1, 1.0),    # β_und
            (3.0, 14.0),   # detection_time
            (0.01, 0.1),   # death_rate
            ],
        NumDimensions = 3,
        MaxTime = 120,  # 2 минуты
        TraceMode = :compact,
        )

        best = best_candidate(result)
        fitness = best_fitness(result)

        println("Оптимальные параметры:")
        println("β_und = $(best[1])")
        println("Время выявления = $(round(Int, best[2])) дней")
        println("Смертность = $(best[3])")
        println("Достигнутые показатели:")
        println("Пик заболеваемости: $(fitness[1])")
        println("Доля умерших: $(fitness[2])")

        save(datadir("optimization_result.jld2"), Dict("best" => best, "fitness" => fitness))
