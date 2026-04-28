module SIRPetri

using AlgebraicPetri
using Catlab.CategoricalAlgebra
using Catlab.Graphics
using OrdinaryDiffEq
using Plots
using DataFrames
using Random

export build_sir_network, simulate_deterministic, simulate_stochastic
export plot_sir, to_graphviz_sir

"""
build_sir_network(β=0.3, γ=0.1)

Создаёт размеченную сеть Петри для модели SIR.
Возвращает (net::LabelledPetriNet, u0::Vector{Float64}, states::Vector{Symbol})
"""
function build_sir_network(β = 0.3, γ = 0.1)
    states = [:S, :I, :R]

    # Создаём сеть Петри, описывая переходы напрямую
    # Переход infection: S + I → I + I
    # Переход recovery: I → R
    net = LabelledPetriNet(
        states,
        :infection => ([:S, :I] => [:I, :I]),
        :recovery => ([:I] => [:R]),
        )

    # Начальная маркировка: S=990, I=10, R=0
    u0 = [990.0, 10.0, 0.0]

    return net, u0, states
end

"""
sir_ode(net, rates)

Возвращает функцию правой части ОДУ для сети Петри.
Используется для детерминированной симуляции.
"""
function sir_ode(net, rates = [0.3, 0.1])
    function f!(du, u, p, t)
        S, I, R = u
        β, γ = rates
        # Пропускные способности (закон действующих масс)
        infection_rate = β * S * I
        recovery_rate = γ * I
        # Изменения
        du[1] = -infection_rate               # dS/dt
        du[2] = infection_rate - recovery_rate # dI/dt
        du[3] = recovery_rate                 # dR/dt
    end
    return f!
end

"""
simulate_deterministic(net, u0, tspan; saveat=0.1, rates=[0.3,0.1])

Выполняет детерминированную ODE-симуляцию.
Возвращает DataFrame с колонками time, S, I, R.
"""
function simulate_deterministic(net, u0, tspan; saveat = 0.1, rates = [0.3, 0.1])
    f = sir_ode(net, rates)
    prob = ODEProblem(f, u0, tspan)
    sol = solve(prob, Tsit5(), saveat = saveat)
    df = DataFrame(time = sol.t)
    df.S = sol[1, :]
    df.I = sol[2, :]
    df.R = sol[3, :]
    return df
end

"""
simulate_stochastic(net, u0, tspan; rates=[0.3,0.1], rng=Random.GLOBAL_RNG)

Стохастическая симуляция (алгоритм Гиллеспи) прямым методом.
Возвращает DataFrame.
"""
function simulate_stochastic(net, u0, tspan; rates = [0.3, 0.1], rng = Random.GLOBAL_RNG)
    u = copy(u0)
    t = 0.0
    times = [t]
    states = [copy(u)]
    β, γ = rates
    while t < tspan[2]
        S, I, R = u
        a_inf = β * S * I
        a_rec = γ * I
        a0 = a_inf + a_rec
        if a0 == 0
            break
        end
        dt = -log(rand(rng)) / a0
        r = rand(rng) * a0
        if r < a_inf
            # Заражение
            u[1] -= 1
            u[2] += 1
        else
            # Выздоровление
            u[2] -= 1
            u[3] += 1
        end
        t += dt
        if t <= tspan[2]
            push!(times, t)
            push!(states, copy(u))
        end
    end
    df = DataFrame(time = times)
    df.S = [s[1] for s in states]
        df.I = [s[2] for s in states]
            df.R = [s[3] for s in states]
                return df
            end

            """
            plot_sir(df)

            Строит график динамики S, I, R из DataFrame.
            """
            function plot_sir(df)
                p = plot(
                    df.time,
                    [df.S, df.I, df.R],
                    label = ["S (Susceptible)" "I (Infected)" "R (Recovered)"],
                    xlabel = "Time",
                    ylabel = "Population",
                    linewidth = 2,
                    )
                return p
            end

            """
            to_graphviz_sir(net)

            Визуализация сети Петри с помощью Graphviz.
            """
            function to_graphviz_sir(net)
                return to_graphviz(net, prog = "dot")
            end

        end # module
