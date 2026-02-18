#!/usr/bin/env julia
# tangle.jl - Генератор отчетов из Literate-скриптов
# Использование: julia tangle.jl <путь_к_скрипту>
using DrWatson
@quickactivate # Активирует текущий проект DrWatson
using Literate

function main()
    if length(ARGS) == 0
        println("""
                Использование: julia tangle.jl <путь_к_скрипту>
                Примеры:
                julia tangle.jl scripts/lab1.jl
                """)
        return
    end
    script_path = ARGS[1]
    if !isfile(script_path)
        error("Файл не найден: $script_path")
    end
    # Пути и имена
    script_dir = dirname(script_path)
    script_name = splitext(basename(script_path))[1]
    println("Генерация из: $script_path")
    # Чистый скрипт (без комментариев)
    scripts_dir = scriptsdir(script_name)
    Literate.script(script_path, scripts_dir; credit=false)
    println(" ✓ Чистый скрипт: $(scripts_dir)/$(script_name).jl")
    # Quarto-документ
    quarto_dir = projectdir("markdown", script_name);
    Literate.markdown(script_path, quarto_dir;
                      flavor=Literate.QuartoFlavor(),
                      name=script_name, credit=false)
    println(" ✓ Quarto: $(quarto_dir)/$(script_name).qmd")
    # Jupyter notebook
    notebooks_dir = projectdir("notebooks", script_name)
    Literate.notebook(script_path, notebooks_dir, name=script_name; execute=false, credit=false)
    println(" ✓ Notebook: $(notebooks_dir)/$(script_name).ipynb")
    println("\nГотово! Все файлы созданы.")
end
# Запуск
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
