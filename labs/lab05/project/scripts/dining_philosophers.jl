using Pkg
Pkg.activate(abspath(joinpath(pwd(), "../project")))
using DrWatson
quickactivate(pwd(), "project")
include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers
using DataFrames, CSV, Plots

N = 5
tmax = 50.0

println("=== Классическая сеть (без арбитра) ===")
net_classic, u0_classic, _ = DiningPhilosophers.build_classical_network(N)
df_classic = DiningPhilosophers.simulate_stochastic(net_classic, u0_classic, tmax)
CSV.write(datadir("dining_classic.csv"), df_classic)
dead = DiningPhilosophers.detect_deadlock(df_classic, net_classic)
println("Deadlock обнаружен: $dead")
plot_classic = DiningPhilosophers.plot_marking_evolution(df_classic, N)
savefig(plotsdir("classic_simulation.png"))

println("\n=== Сеть с арбитром ===")
net_arb, u0_arb, _ = DiningPhilosophers.build_arbiter_network(N)
df_arb = DiningPhilosophers.simulate_stochastic(net_arb, u0_arb, tmax)
CSV.write(datadir("dining_arbiter.csv"), df_arb)
dead_arb = DiningPhilosophers.detect_deadlock(df_arb, net_arb)
println("Deadlock обнаружен: $dead_arb")
plot_arb = DiningPhilosophers.plot_marking_evolution(df_arb, N)
savefig(plotsdir("arbiter_simulation.png"))
