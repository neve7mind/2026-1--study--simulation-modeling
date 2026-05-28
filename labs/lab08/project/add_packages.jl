##!/usr/bin/env julia
## add_packages.jl

using Pkg
Pkg.activate(".") # Активируем текущий проект
## ОСНОВНЫЕ ПАКЕТЫ ДЛЯ РАБОТЫ
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

println("Установка базовых пакетов...")
Pkg.add(packages)
println("\n✅ Все пакеты установлены!")
println("Для проверки: using DrWatson, DifferentialEquations, Plots")
