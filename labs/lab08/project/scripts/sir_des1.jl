using Pkg
Pkg.activate("../project")
using DrWatson
@quickactivate "project"

include(srcdir("sir_model1.jl"))
using Random, StatsPlots, BenchmarkTools, CSV, Dates

# Создаем структуры директорий, если они отсутствуют
mkpath(plotsdir())
mkpath(datadir("sims"))

# Базовые параметры
const TMAX = 50.0
const U0 = [980, 10, 10, 0] # S, E, I, R

# ------------------------------------------------------------------
# ЭКСПЕРИМЕНТ 1: Базовый прогон (Стохастический SEIR + Демография + Вакцинация)
# ------------------------------------------------------------------
println("=== Запуск базового эксперимента SEIR ===")
Random.seed!(1234)

model_base = MakeSEIRModel(U0, [0.05, 10.0, 0.25, 0.5],
                           deterministic_recovery=false,
                           μ_dem=0.01,       # Смертность 1% в ед. времени
                           birth_rate=5.0)   # Рождение 5 новых S в ед. времени

# Планируем вакцинацию на t=15.0 для 40% здорового населения
activate!(model_base, vaccination=(15.0, 0.4))
seir_run!(model_base, TMAX)
data_base = out(model_base)

# Сохранение базового прогона в CSV
CSV.write(datadir("sims", "seir_base_experiment.csv"), data_base)

# Визуализация базового прогона
p1 = @df data_base plot(:t, [:S :E :I :R :D],
                        labels=["S" "E" "I" "R" "D"],
                        xlab="Время", ylab="Численность",
                        title="Дискретно-событийная SEIR модель с демографией и вакцинацией", lw=2)
savefig(p1, plotsdir("seir_base_dynamic.png"))

# ------------------------------------------------------------------
# ЭКСПЕРИМЕНТ 2: Детерминированное vs Стохастическое выздоровление
# ------------------------------------------------------------------
println("\n=== Сравнение стохастического и детерминированного выздоровления ===")
Random.seed!(1234)
m_stoch = MakeSEIRModel(U0, [0.05, 10.0, 0.25, 0.5], deterministic_recovery=false)
activate!(m_stoch); seir_run!(m_stoch, TMAX); df_stoch = out(m_stoch)

Random.seed!(1234)
m_det = MakeSEIRModel(U0, [0.05, 10.0, 0.25, 0.5], deterministic_recovery=true)
activate!(m_det); seir_run!(m_det, TMAX); df_det = out(m_det)

p2 = plot(df_stoch.t, df_stoch.I, label="Инфицированные (Стохаст.)", color=:red, lw=1.5)
plot!(p2, df_det.t, df_det.I, label="Инфицированные (Детерм.)", color=:blue, lw=2, linestyle=:dash,
      title="Влияние характера распределения выздоровления", xlab="Время", ylab="Количество")
savefig(p2, plotsdir("seir_recovery_comparison.png"))

# ------------------------------------------------------------------
# ЭКСПЕРИМЕНТ 3: Анализ чувствительности к параметрам (Бета-вариации)
# ------------------------------------------------------------------
println("\n=== Анализ чувствительности параметров (Тестирование вариаций β) ===")
betas = [0.03, 0.05, 0.08]
p3 = plot(title="Анализ чувствительности: Вариации параметров зараяжаемости (β)", xlab="Время", ylab="Пик инфицированных (I)")

for β_val in betas
    Random.seed!(1234)
    m_test = MakeSEIRModel(U0, [β_val, 10.0, 0.25, 0.5])
    activate!(m_test)
    seir_run!(m_test, TMAX)
    df_test = out(m_test)

    peak_I = maximum(df_test.I) # Исправлено: чистая интерполяция строк без бэкслешей
    peak_t = df_test.t[argmax(df_test.I)]
    println("Параметр β = $β_val | Пик заболеваемости (I): $peak_I в момент времени t = $peak_t")

    CSV.write(datadir("sims", "sensitivity_beta_$(β_val).csv"), df_test) # Исправлено: чистая интерполяция в путях файлов

    plot!(p3, df_test.t, df_test.I, label="β = $β_val", lw=2)
end
savefig(p3, plotsdir("seir_sensitivity_analysis.png"))

# ------------------------------------------------------------------
# ЭКСПЕРИМЕНТ 4: Оценка производительности (Бенчмарк для N=10 000)
# ------------------------------------------------------------------
println("\n=== Запуск бенчмарка производительности для крупной популяции ===")
u0_large = [9900, 0, 100, 0] # N = 10000
model_large = MakeSEIRModel(u0_large, [0.05, 10.0, 0.25, 0.5])
activate!(model_large)

# Исправлено: убран бэкслеш перед знаком доллара для интерполяции в макрос
benchmark_result = @benchmark seir_run!($model_large, 20.0)
show(stdout, MIME("text/plain"), benchmark_result)
println("\n\nТестирование успешно завершено. Все графики сохранены в директорию `plots/`.")
