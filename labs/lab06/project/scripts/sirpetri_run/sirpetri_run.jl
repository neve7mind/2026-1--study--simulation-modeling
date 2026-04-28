using Pkg
Pkg.activate("../project")
using DrWatson
@quickactivate "project"
using Random
include(srcdir("SIRPetri.jl"))
using .SIRPetri
using DataFrames, CSV, Plots

β = 0.3
γ = 0.1
tmax = 100.0

net, u0, states = SIRPetri.build_sir_network(β, γ)

df_det = SIRPetri.simulate_deterministic(net, u0, (0.0, tmax), saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

Random.seed!(123)
df_stoch = SIRPetri.simulate_stochastic(net, u0, (0.0, tmax), rates = [β, γ])
CSV.write(datadir("sir_stoch.csv"), df_stoch)

p_det = SIRPetri.plot_sir(df_det)
savefig(plotsdir("sir_det_dynamics.png"))

p_stoch = SIRPetri.plot_sir(df_stoch)
savefig(plotsdir("sir_stoch_dynamics.png"))

println("Базовый прогон завершён. Результаты в data/ и plots/")
