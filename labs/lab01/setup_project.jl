##!/usr/bin/env julia
## setup_project.jl

using Pkg
Pkg.add("DrWatson")
using DrWatson

## Создание проекта
project_name = "project"
initialize_project(project_name; authors="ivmurashov", git=false)
println("✅ Проект создан: ", project_name)
println("� Перейдите в директорию: cd ", project_name)
