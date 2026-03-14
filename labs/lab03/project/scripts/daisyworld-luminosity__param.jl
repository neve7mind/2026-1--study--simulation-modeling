using Pkg
Pkg.activate("../project")
using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
using CairoMakie

include(srcdir("daisyworld.jl"))


black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]

## Параметры эксперимента
param_dict = Dict(
    :griddims => (30, 30),
    :max_age => [25, 40],
    :init_white => [0.2, 0.8],
    :init_black => 0.2,
    :albedo_white => 0.75,
    :albedo_black => 0.25,
    :surface_albedo => 0.4,
    :solar_change => 0.005,
    :solar_luminosity => 1.0,
    :scenario => :ramp,
    :seed => 165,
    )

## Создаём список всех комбинаций
params_list = dict_list(param_dict)

for params in params_list

    model = daisyworld(;params...)

    temperature(model) = StatsBase.mean(model.temperature)
    mdata = [temperature, :solar_luminosity]

    agent_df, model_df = run!(model, 1000; adata = adata, mdata = mdata)

    figure = CairoMakie.Figure(size = (600, 600));
    ax1 = figure[1, 1] = Axis(figure, ylabel = "daisy count")
    blackl = lines!(ax1, agent_df[!, :time], agent_df[!, :count_black], color = :red)
    whitel = lines!(ax1, agent_df[!, :time], agent_df[!, :count_white], color = :blue)
    figure[1, 2] = Legend(figure, [blackl, whitel], ["black", "white"])

    ax2 = figure[2, 1] = Axis(figure, ylabel = "temperature")
    ax3 = figure[3, 1] = Axis(figure, xlabel = "tick", ylabel = "luminosity")
    lines!(ax2, model_df[!, :time], model_df[!, :temperature], color = :red)
    lines!(ax3, model_df[!, :time], model_df[!, :solar_luminosity], color = :red)
    for ax in (ax1, ax2); ax.xticklabelsvisible = false; end


    plt_name = savename("daisy-luminosity",params) * ".png"
    save(plotsdir(plt_name), figure)

end
