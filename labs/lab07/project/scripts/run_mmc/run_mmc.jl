using Pkg
Pkg.activate("../project")
using DrWatson
@quickactivate "project"

using StableRNGs
using Distributions
using ConcurrentSim
using ResumableFunctions
using DataFrames
using Plots
using CSV

include(srcdir("mmc_logic.jl"))

#set simulation parameters
rng = StableRNG(123)
num_customers = 500 # total number of customers generated

num_servers = 2 # number of servers
mu = 1.0 / 2 # service rate
lam = 0.9 # arrival rate
arrival_dist = Exponential(1 / lam) # interarrival time distribution
service_dist = Exponential(1 / mu) # service time distribution

times_data = DataFrame(id = Int[], arrival = Float64[], wait = Float64[])

function setup_and_run()
    sim = Simulation() # initialize simulation environment
    server = Resource(sim, num_servers) # initialize servers
    arrival_time = 0.0
    for i = 1:num_customers # initialize customers
        arrival_time += rand(rng, arrival_dist)
        @process customer(sim, server, i, arrival_time, service_dist, rng, times_data)
    end
    run(sim) # run simulation
end

setup_and_run()

CSV.write(datadir("sim_results_mmc.csv"), times_data)

p1 = histogram(times_data.wait,
               title = "Распределение времени ожидания (M/M/c)",
               xlabel = "Время ожидания в очереди",
               ylabel = "Частота",
               label = "Заявки",
               color = :blue,
               fmt = :png
               )

p2 = plot(times_data.arrival, times_data.id,
               title = "Поток заявок",
               xlabel = "Момент времени t",
               ylabel = "ID клиента",
               label = "Прибытие",
               color = :red,
               fmt = :png
               )

final_plot = plot(p1, p2, layout = (2, 1), size = (800, 600))
savefig(plotsdir("mmc_analysis.png"))

println("Моделирование завершено. Графики сохранены в plots/, данные в data/.")
