using DrWatson
@quickactivate "project"
include(srcdir("SIRPetri.jl"))
using .SIRPetri
using DataFrames, CSV, Plots

β = 0.4
γ = 0.1
tmax = 50.0

net, u0, _ = SIRPetri.build_sir_network(β, γ)
df = SIRPetri.simulate_deterministic(net, u0, (0.0, tmax), saveat = 0.5, rates = [β, γ])

anim = @animate for i in 1:size(df, 1)
    time_val = hasproperty(df, :t) ? df.t[i] : (hasproperty(df, :timestamp) ? df.timestamp[i] : i)
    vals = [df.S[i], df.I[i], df.R[i]]
    plot(
        ["S", "I", "R"],
        vals,
        grid = :both,
        marker = (:circle, 8, :white, stroke(2, :blue)),
        line = (:path, :blue),
        ylim = (0, maximum(df.S) * 1.1), # Автоматический предел на основе начального S
        title = "SIR dynamics at t = $(round(time_val, digits=1))",
        ylabel = "Population",
        xlabel = "Compartment",
        label = "S",
        legend = :topright
        )
end

gif(anim, plotsdir("sir_animation.gif"), fps = 15)

println("Анимация сохранена в plots/sir_animation.gif")
