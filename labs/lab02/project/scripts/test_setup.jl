##!/usr/bin/env julia
## test_setup.jl
using DrWatson
@quickactivate "project"
println("✅ Проект активирован: ", projectdir())
## Проверка пакетов
packages = [
    "DrWatson", # Организация проекта
    "DifferentialEquations", # Решение ОДУ
    "Plots", # Визуализация
    "DataFrames", # Таблицы данных
    "CSV", # Работа с CSV
    "JLD2", # Сохранение данных
    "Literate", # Literate programming
    "IJulia", # Jupyter notebook
    "BenchmarkTools", # Бенчмаркинг
    "Quarto" # Создание отчетов
    ]
println("\nПроверка пакетов:")
for pkg in packages
    try
        eval(Meta.parse("using $pkg"))
        println(" ✓ $pkg")
        catch e
        println(" ✗ $pkg: Ошибка загрузки")
    end
end
## Проверка путей
println("\nСтруктура проекта:")
println(" Корень: ", projectdir())
println(" Данные: ", datadir())
println(" Скрипты: ", srcdir())
println(" Графики: ", plotsdir())
