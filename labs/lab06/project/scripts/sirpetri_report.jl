using Pkg
Pkg.activate("../project")
using DrWatson
@quickactivate "project"
using DataFrames, CSV, Plots

df_det = CSV.read(datadir("sir_det.csv"), DataFrame)
df_stoch = CSV.read(datadir("sir_stoch.csv"), DataFrame)
df_scan = CSV.read(datadir("sir_scan.csv"), DataFrame)

# Сравнение детерминированной и стохастической динамики
p1 = plot(
    df_det.time,
    [df_det.I df_stoch.I[1:length(df_det.time)]],
    label = ["Deterministic I" "Stochastic I"],
    xlabel = "Time",
    ylabel = "Infected",
    title = "Comparison",
    )
savefig(plotsdir("comparison.png"))

# Зависимость пика I от β
p2 = plot(
    df_scan.β,
    df_scan.peak_I,
    marker = :circle,
    xlabel = "β",
    ylabel = "Peak I",
    title = "Sensitivity",
    )
savefig(plotsdir("sensitivity.png"))

println("Отчётные графики сохранены в plots/")
