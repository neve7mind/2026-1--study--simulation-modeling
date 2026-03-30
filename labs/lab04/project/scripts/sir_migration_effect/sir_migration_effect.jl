using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots, CSV, Random

include(srcdir("sir_model.jl"))

function create_migration_matrix(C, intensity)
    M = ones(C, C) .* intensity ./ (C-1)
    for i = 1:C
        M[i, i] = 1 - intensity
    end
    return M
end

function peak_time(p)
    migration_rates = create_migration_matrix(p[:C], p[:migration_intensity]) # Создаём матрицу миграции на основе интенсивности
    model = initialize_sir(;
                           Ns = p[:Ns],
                           β_und = p[:β_und],
                           β_det = p[:β_det],
                           infection_period = p[:infection_period],
                           detection_time = p[:detection_time],
                           death_rate = p[:death_rate],
                           reinfection_probability = p[:reinfection_probability],
                           Is = p[:Is],
                           seed = p[:seed],
                           migration_rates = migration_rates,
                           )

    infected_frac(model) = count(a.status == :I for a in allagents(model)) / nagents(model)
        peak = 0.0
        peak_step = 0

        for step = 1:p[:n_steps]

            agent_ids = collect(allids(model))  # Ручной шаг
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

            frac = infected_frac(model)
            if frac > peak
                peak = frac
                peak_step = step
            end
        end

        return (peak_time = peak_step, peak_value = peak)
    end

    migration_intensities = 0.0:0.1:0.5
    seeds = [42, 43, 44]

    params_list = []
    for mig in migration_intensities
        for s in seeds
            push!(
                params_list,
                Dict(
                    :migration_intensity => mig,  # скаляр
                    :C => 3,
                    :Ns => [1000, 1000, 1000],
                    :β_und => [0.5, 0.5, 0.5],
                    :β_det => [0.05, 0.05, 0.05],
                    :infection_period => 14,
                    :detection_time => 7,
                    :death_rate => 0.02,
                    :reinfection_probability => 0.1,
                    :Is => [1, 0, 0],
                    :seed => s,
                    :n_steps => 150,
                    ),
                )
        end
    end

    results = []
    for params in params_list
        data = peak_time(params)
        push!(results, merge(params, Dict(pairs(data))))
        println(
            "Завершён эксперимент с migration_intensity = $(params[:migration_intensity]), seed = $(params[:seed])",
            )
    end

    df = DataFrame(results)
    CSV.write(datadir("migration_scan_all.csv"), df)

    using Statistics
    grouped = combine(
        groupby(df, [:migration_intensity]),
        :peak_time => mean => :mean_peak_time,
        :peak_value => mean => :mean_peak_value,
        )

    plot(
        grouped.migration_intensity,
        grouped.mean_peak_time,
        marker = :circle,
        xlabel = "Интенсивность миграции",
        ylabel = "Время до пика (дни)",
        label = "Время пика",
        )
    plot!(
        grouped.migration_intensity,
        grouped.mean_peak_value .* 3000,
        marker = :square,
        xlabel = "Интенсивность миграции",
        ylabel = "Численность в пике",
        label = "Пиковая заболеваемость",
        )
    savefig(plotsdir("migration_effect.png"))

    println("Результаты сохранены в data/migration_scan_all.csv и plots/migration_effect.png")
