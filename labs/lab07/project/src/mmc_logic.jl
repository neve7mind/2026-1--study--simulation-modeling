using StableRNGs
using Distributions
using ConcurrentSim
using ResumableFunctions
using DataFrames
using Random
using CSV

#set simulation parameters
rng = StableRNG(123)
num_customers = 10 # total number of customers generated

# set queue parameters
num_servers = 2 # number of servers
mu = 1.0 / 2 # service rate
lam = 0.9 # arrival rate
arrival_dist = Exponential(1 / lam) # interarrival time distribution
service_dist = Exponential(1 / mu) # service time distribution

# define customer behavior
@resumable function customer(
    env::Environment,
    server::Resource,
    id::Integer,
    t_a::Float64,
    d_s::Distribution,
    rng::AbstractRNG,
    times_data::DataFrame
    )
    @yield timeout(env, t_a) # customer arrives
    arrival_time = now(env)
    @yield request(server) # customer starts service
    wait_time = now(env) - arrival_time
    push!(times_data, (id = id, arrival = arrival_time, wait = wait_time))
    @yield timeout(env, rand(rng, d_s)) # server is busy
    @yield unlock(server) # customer exits service
end
