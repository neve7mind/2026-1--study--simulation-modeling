using Agents, Random
using Agents.Graphs
using StatsBase: sample, Weights
using Distributions: Poisson

using DrWatson: @dict

# Определение типа агента
@agent struct Person(GraphAgent)
    days_infected::Int  # количество дней с момента заражения
    status::Symbol      # :S, :I, :R
end

# Функция инициализации модели
function initialize_sir(;
                        Ns = [1000, 1000, 1000],        # численность по трём городам
                        migration_rates = nothing,       # матрица миграции
                        β_und = [0.5, 0.5, 0.5],        # передача невыявленными
                        β_det = [0.05, 0.05, 0.05],      # передача выявленными
                        infection_period = 14,
                        detection_time = 7,
                        death_rate = 0.02,
                        reinfection_probability = 0.1,
                        Is = [0, 0, 1],                  # начальное количество инфицированных
                        seed = 42,
                        n_steps = 100,
                        )
    rng = Xoshiro(seed)
    C = length(Ns)  # количество городов

    # Если матрица миграции не задана, создаём реалистичную
    if migration_rates === nothing
        migration_rates = zeros(C, C)
        for i = 1:C
            for j = 1:C
                # Вероятность миграции пропорциональна размеру целевого города
                migration_rates[i, j] = (Ns[i] + Ns[j]) / Ns[i]
            end
        end
        # Нормализация
        for i = 1:C
            migration_rates[i, :] ./= sum(migration_rates[i, :])
        end
    end

    properties = @dict(
        Ns,
        β_und,
        β_det,
        migration_rates,
        infection_period,
        detection_time,
        death_rate,
        reinfection_probability,
        C
        )

    # Пространство — полный граф (все города связаны)
    space = GraphSpace(complete_graph(C))
    model = StandardABM(Person, space; properties, rng, (agent_step!) = (sir_agent_step!))

    # Заполняем города агентами
    for city = 1:C
        for _ = 1:Ns[city]
            add_agent!(city, model, 0, :S)
        end
    end

    # Инфицируем начальных носителей
    for city = 1:C
        if Is[city] > 0
            # Получаем список агентов в городе
            city_agents = ids_in_position(city, model)
            # Выбираем случайных для инфицирования
            infected_ids = sample(rng, city_agents, Is[city]; replace = false)
            for id in infected_ids
                agent = model[id]
                agent.status = :I
                agent.days_infected = 1
            end
        end
    end

    return model
end

# Шаг агента
function sir_agent_step!(agent, model)
    # Миграция
    migrate!(agent, model)

    # Передача инфекции (только если агент инфицирован)
    if agent.status == :I
        transmit!(agent, model)
    end

    # Обновление счётчика дней для инфицированных
    if agent.status == :I
        agent.days_infected += 1
    end

    # Выздоровление или смерть
    recover_or_die!(agent, model)
end

# Миграция между городами
function migrate!(agent, model)
    current_city = agent.pos
    # Выбираем целевой город согласно вероятностям
    probs = model.migration_rates[current_city, :]
    target = sample(abmrng(model), 1:model.C, Weights(probs))

    if target ≠ current_city
        move_agent!(agent, target, model)
    end
end

# Передача инфекции
function transmit!(agent, model)
    # Определяем интенсивность заражения в зависимости от стадии
    rate = if agent.days_infected < model.detection_time
        model.β_und[agent.pos]  # невыявленный — высокая заразность
    else
        model.β_det[agent.pos]  # выявленный — низкая заразность
    end

    # Количество заражённых за день — пуассоновский процесс
    n_infections = rand(abmrng(model), Poisson(rate))
    n_infections == 0 && return nothing

    # Получаем всех агентов в той же локации, кроме самого заразного
    neighbors = [a for a in agents_in_position(agent.pos, model) if a.id != agent.id]

        # Перемешиваем для случайного порядка
        shuffle!(abmrng(model), neighbors)

        for contact in neighbors
            # Проверяем возможность заражения
            if contact.status == :S
                contact.status = :I
                contact.days_infected = 1
                n_infections -= 1
                n_infections == 0 && return nothing
                elseif contact.status == :R && rand(abmrng(model)) ≤ model.reinfection_probability
                contact.status = :I
                contact.days_infected = 1
                n_infections -= 1
                n_infections == 0 && return nothing
            end
        end
    end

    # Выздоровление или смерть
    function recover_or_die!(agent, model)
        if agent.status == :I && agent.days_infected ≥ model.infection_period
            if rand(abmrng(model)) ≤ model.death_rate
                remove_agent!(agent, model)  # смерть (исправлено)
            else
                agent.status = :R  # выздоровление
                agent.days_infected = 0
            end
        end
    end

    # Вспомогательные функции для сбора данных
    infected_count(model) = count(a.status == :I for a in allagents(model))
        recovered_count(model) = count(a.status == :R for a in allagents(model))
            susceptible_count(model) = count(a.status == :S for a in allagents(model))
                total_count(model) = nagents(model)
