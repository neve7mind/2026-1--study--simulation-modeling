using ResumableFunctions, ConcurrentSim, Distributions, DataFrames, Random, CSV, Dates

# Вспомогательные функции для обновления массивов динамики численности
function increment!(a::Array{Int64}) push!(a, a[end] + 1) end
function decrement!(a::Array{Int64}) push!(a, a[end] - 1) end
function carryover!(a::Array{Int64}) push!(a, a[end]) end

# Структура агента-индивидуума (расширена состоянием :E для SEIR)
mutable struct SEIRPerson
    id::Int64
    status::Symbol # :S, :E, :I, :R, :D (D - умерший)
end

# Основная структура модели SEIR со всеми модификациями
mutable struct SEIRModel
    sim::ConcurrentSim.Simulation
    β::Float64          # Вероятность заражения при контакте
    c::Float64          # Частота контактов
    γ::Float64          # Интенсивность выздоровления
    σ::Float64          # Интенсивность перехода из E в I (Латентный период)
    μ_dem::Float64      # Интенсивность естественной смертности
    birth_rate::Float64 # Интенсивность рождения новых индивидов
    deterministic_recovery::Bool # Флаг детерминированного времени болезни

    # Временные ряды для сбора статистики
    ta::Array{Float64}
    Sa::Array{Int64}
    Ea::Array{Int64}
    Ia::Array{Int64}
    Ra::Array{Int64}
    Da::Array{Int64} # Смерти

    allIndividuals::Array{SEIRPerson}
end

# Функция общего обновления временных шкал
function log_state!(sim::ConcurrentSim.Simulation, m::SEIRModel)
    push!(m.ta, ConcurrentSim.now(sim))
end

# Исправленная функция изменения состояний с явной проверкой типов
function update_stats!(m::SEIRModel, s, e, i, r, d)
    s === true ? increment!(m.Sa) : (s === false ? decrement!(m.Sa) : carryover!(m.Sa))
    e === true ? increment!(m.Ea) : (e === false ? decrement!(m.Ea) : carryover!(m.Ea))
    i === true ? increment!(m.Ia) : (i === false ? decrement!(m.Ia) : carryover!(m.Ia))
    r === true ? increment!(m.Ra) : (r === false ? decrement!(m.Ra) : carryover!(m.Ra))
    d === true ? increment!(m.Da) : (d === false ? decrement!(m.Da) : carryover!(m.Da))
end

# ОТДЕЛЬНЫЙ ПРОЦЕСС: Мониторинг смерти конкретного агента
@resumable function death_monitor_proc(env::ConcurrentSim.Simulation, individual::SEIRPerson, m::SEIRModel)
    if m.μ_dem > 0.0
        @yield timeout(env, rand(Exponential(1/m.μ_dem)))
        if individual.status != :D
            log_state!(env, m)
            if individual.status == :S decrement!(m.Sa); carryover!(m.Ea); carryover!(m.Ia); carryover!(m.Ra); increment!(m.Da)
                elseif individual.status == :E carryover!(m.Sa); decrement!(m.Ea); carryover!(m.Ia); carryover!(m.Ra); increment!(m.Da)
                elseif individual.status == :I carryover!(m.Sa); carryover!(m.Ea); decrement!(m.Ia); carryover!(m.Ra); increment!(m.Da)
                elseif individual.status == :R carryover!(m.Sa); carryover!(m.Ea); carryover!(m.Ia); decrement!(m.Ra); increment!(m.Da)
            end
            individual.status = :D
        end
    end
end

# Основной жизненный цикл агента (SEIR переходы)
@resumable function live(env::ConcurrentSim.Simulation, individual::SEIRPerson, m::SEIRModel)
    # Запуск монитора смерти
    @process death_monitor_proc(env, individual, m)

    # Состояние S: Ожидание контактов и заражения
    while individual.status == :S
        @yield timeout(env, rand(Exponential(1/m.c)))
        if individual.status == :D return end # Если агент уже мертв от демографии

        # Выбор случайного живого собеседника
        alive_pop = filter(x -> x.status != :D, m.allIndividuals)
        if length(alive_pop) > 1
            alter = rand(alive_pop)
            while alter.id == individual.id
                alter = rand(alive_pop)
            end

            # Если контакт с инфицированным -> переход в латентную фазу E
            if alter.status == :I && rand(Uniform(0, 1)) < m.β
                log_state!(env, m)
                individual.status = :E
                update_stats!(m, false, true, nothing, nothing, nothing)
            end
        end
    end

    # Состояние E: Латентный период
    if individual.status == :E
        @yield timeout(env, rand(Exponential(1/m.σ)))
        if individual.status == :D return end
        log_state!(env, m)
        individual.status = :I
        update_stats!(m, nothing, false, true, nothing, nothing)
    end

    # Состояние I: Инфекционный период (Болезнь)
    if individual.status == :I
        if m.deterministic_recovery
            @yield timeout(env, 1/m.γ) # Детерминированная длительность
        else
            @yield timeout(env, rand(Exponential(1/m.γ))) # Стохастическая длительность
        end
        if individual.status == :D return end
        log_state!(env, m)
        individual.status = :R
        update_stats!(m, nothing, nothing, false, true, nothing)
    end
end

# Процесс демографии: Постоянный приток новорожденных (в класс S)
@resumable function birth_process(env::ConcurrentSim.Simulation, m::SEIRModel)
    id_counter = length(m.allIndividuals) + 1
    while true
        @yield timeout(env, rand(Exponential(1/m.birth_rate)))
        log_state!(env, m)
        new_person = SEIRPerson(id_counter, :S)
        push!(m.allIndividuals, new_person)
        update_stats!(m, true, nothing, nothing, nothing, nothing)
        @process live(env, new_person, m)
        id_counter += 1
    end
end

# Процесс вакцинации по таймеру
@resumable function vaccinate_process(env::ConcurrentSim.Simulation, m::SEIRModel, v_time::Float64, fraction::Float64)
    @yield timeout(env, v_time)
    log_state!(env, m)

    susceptibles = filter(x -> x.status == :S, m.allIndividuals)
    num_to_vaccinate = round(Int, fraction * length(susceptibles))

    if num_to_vaccinate > 0
        vaccinated = shuffle(susceptibles)[1:num_to_vaccinate]
        for person in vaccinated
            person.status = :R
        end
        push!(m.Sa, m.Sa[end] - num_to_vaccinate)
        carryover!(m.Ea)
        carryover!(m.Ia)
        push!(m.Ra, m.Ra[end] + num_to_vaccinate)
        carryover!(m.Da)
    end
    println("[Событие] Вакцинация проведена в t = $v_time. Вакцинировано: $num_to_vaccinate")
end

# Конструктор генерации модели
function MakeSEIRModel(u0, p; deterministic_recovery=false, μ_dem=0.0, birth_rate=0.0)
    S, E, I, R = u0
    β, c, γ, σ = p

    sim = ConcurrentSim.Simulation()
    allIndividuals = SEIRPerson[]

    id = 1
    for i in 1:S; push!(allIndividuals, SEIRPerson(id, :S)); id+=1; end
    for i in 1:E; push!(allIndividuals, SEIRPerson(id, :E)); id+=1; end
    for i in 1:I; push!(allIndividuals, SEIRPerson(id, :I)); id+=1; end
    for i in 1:R; push!(allIndividuals, SEIRPerson(id, :R)); id+=1; end

    ta, Sa, Ea, Ia, Ra, Da = [0.0], [S], [E], [I], [R], [0]

    return SEIRModel(sim, β, c, γ, σ, μ_dem, birth_rate, deterministic_recovery, ta, Sa, Ea, Ia, Ra, Da, allIndividuals)
end

function activate!(m::SEIRModel; vaccination=nothing)
    for individual in m.allIndividuals
        @process live(m.sim, individual, m)
    end
    if m.birth_rate > 0.0
        @process birth_process(m.sim, m)
    end
    if !isnothing(vaccination)
        @process vaccinate_process(m.sim, m, vaccination[1], vaccination[2])
    end
end

function seir_run!(m::SEIRModel, tf::Float64)
    ConcurrentSim.run(m.sim, tf)
end

function out(m::SEIRModel)
    return DataFrame(t=m.ta, S=m.Sa, E=m.Ea, I=m.Ia, R=m.Ra, D=m.Da)
end
