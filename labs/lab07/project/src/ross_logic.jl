using ResumableFunctions
using ConcurrentSim
using Distributions
using DataFrames
using Random

@resumable function machine(
    env::Environment,
    repair_facility::Resource,
    spares::Store{Int},
    log_data::DataFrame,
    local_rng::AbstractRNG,
    dist_F::Distribution,
    dist_G::Distribution
    )
    while true
        # 1. РАБОТА
        @yield timeout(env, rand(local_rng, dist_F))

        # 2. ПОЛОМКА
        push!(log_data, (
            time = now(env),
            queue_length = length(repair_facility.put_queue),
            active_repairers = repair_facility.capacity - repair_facility.level,
            spares_left = length(spares.items)
            ))

        # 3. ЗАМЕНА
        # Используем селектор событий. Если timeout(0) сработает быстрее, чем take!, значит склада нет.
        get_spare_ev = take!(spares)
        fail_timeout = timeout(env, 0.0)
        res = @yield get_spare_ev | fail_timeout

        # Проверяем, наступило ли событие извлечения из Store
        if !haskey(res, get_spare_ev)
            throw(StopSimulation("System Crash: No more spares at time $(now(env))"))
        end

        # 4. РЕМОНТ
        @yield request(repair_facility)
        @yield timeout(env, rand(local_rng, dist_G))
        @yield release(repair_facility)

        # 5. ВОЗВРАТ
        @yield put!(spares, 1)
        push!(log_data, (
            time = now(env),
            queue_length = length(repair_facility.put_queue),
            active_repairers = repair_facility.capacity - repair_facility.level,
            spares_left = length(spares.items)
            ))
    end
end

@resumable function start_sim_proc(
    env::Environment,
    repair_facility::Resource,
    spares::Store{Int},
    log_data::DataFrame,
    N_val::Int,
    S_val::Int,
    local_rng::AbstractRNG,
    dist_F::Distribution,
    dist_G::Distribution
    )
    for i in 1:S_val
        @yield put!(spares, 1)
    end

    for i in 1:N_val
        @process machine(env, repair_facility, spares, log_data, local_rng, dist_F, dist_G)
    end
end
