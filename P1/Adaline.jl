include("Neurona_pkg.jl")
include("Capa_pkg.jl")
include("RedNeuronal_pkg.jl")
using .Neurona_pkg
using .Capa_pkg
using .RedNeuronal_pkg

using ArgParse  # import Pkg; Pkg.add("ArgParse")
using DelimitedFiles

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--input_file"
            help = "Fichero con los valores de entrada para la red frio-calor."
            required = true
        "--output_file"
            help = "Fichero en el que se van a almacenar los valores de la neurona en cada instante de tiempo."
            required = true
        "--tasa_aprendizaje"
            help = "Tasa de aprendizaje del adaline."
            arg_type = Float64
            required = true
        "--max_epocas"
            help = "Número máximo de épocas para realizar el entrenamiento."
            arg_type = Int64
            required = true
        "--tolerancia"
            help = "Si el mayor cambio de pesos es menor que esta tolerancia, el entrenamiento finaliza."
            arg_type = Float64
            required = true
    end

    return parse_args(s)
end


function crear_adaline(num_atributos::Int64, num_clases::Int64)
    red = RedNeuronal_pkg.Crear()

    capa_entrada = Capa_pkg.Crear()

    for i in 1:num_atributos
        x = Neurona_pkg.Crear(1.0, Neurona_pkg.Directa)
        Capa_pkg.Añadir(capa_entrada, x)
    end

    sesgo = Neurona_pkg.Crear(1.0, Neurona_pkg.Sesgo)
    Capa_pkg.Añadir(capa_entrada, sesgo)
    
    RedNeuronal_pkg.Añadir(red, capa_entrada)

    capa_salida = Capa_pkg.Crear()

    for i in 1:num_clases
        x = Neurona_pkg.Crear(0.0, Neurona_pkg.Adaline)
        Capa_pkg.Añadir(capa_salida, x)
    end

    RedNeuronal_pkg.Añadir(red, capa_salida)
    
    for neur_in in capa_entrada.neuronas
        for neur_out in capa_salida.neuronas
            Neurona_pkg.Conectar(neur_in, neur_out, 0.0)
        end
    end

    return red
end

function avanzar_ciclo(red::RedNeuronal_pkg.RedNeuronal, valores_entrada::Vector{Float64})
    capa_entrada = red.capas[1]
    for i in 1:size(valores_entrada, 1)
        Neurona_pkg.Inicializar(capa_entrada.neuronas[i], valores_entrada[i])
    end
    RedNeuronal_pkg.Disparar(red)
    RedNeuronal_pkg.Inicializar(red)
    RedNeuronal_pkg.Propagar(red)
end


function entrenamiento_adaline(red::RedNeuronal_pkg.RedNeuronal, tasa_aprendizaje::Float64,
    num_atributos::Int64, atributos::Vector{Float64}, num_clases::Int64,
    clases_verdaderas::Vector{Float64}, tolerancia::Float64)
    capa_entrada = red.capas[1]
    capa_salida = red.capas[2]
    # Los valores de salida de la última capa deben ser actualizados para obtener la respuesta final
    Capa_pkg.Disparar(capa_salida)

    max_delta = -Inf

    for clase_index in 1:num_clases
        for atributo_index in 1:num_atributos
            conexion = capa_entrada.neuronas[atributo_index].conexiones[clase_index]
            conexion.peso_anterior = conexion.peso
            # En fase de entrenamiento, se usa el valor de entrada como respuesta (sin activación) # TODO: ojo que al predecir sí que hay que usar el valor de salida
            y_in = capa_salida.neuronas[clase_index].valor_entrada
            t = clases_verdaderas[clase_index]
            delta = tasa_aprendizaje * (t-y_in) * atributos[atributo_index]
            conexion.peso += delta

            if delta > max_delta
                max_delta = delta
            end
        end
    end

    if max_delta < tolerancia
        fin_entrenamiento = true
    else
        fin_entrenamiento = false
    end

    return fin_entrenamiento
end

function print_pesos(red::RedNeuronal_pkg.RedNeuronal)
    for capa in red.capas
        for neurona in capa.neuronas
            for conexion in neurona.conexiones
                println(conexion.peso)
            end
        end
    end
    println("_______")
end



function main()

    parsed_args = parse_commandline()

    input_file = parsed_args["input_file"]
    output_file = parsed_args["output_file"]
    tasa_aprendizaje = parsed_args["tasa_aprendizaje"]
    max_epocas = parsed_args["max_epocas"]
    tolerancia = parsed_args["tolerancia"]

    """
    if size(ARGS) != (2,)
        println("Número incorrecto de argumentos. Debe ejecutar:")
        println("julia FrioCalor.jl [input_file] [output_file]")
        return 
    end

    input_file = ARGS[1]
    output_file = ARGS[2]
    """

    file_lines = readlines(input_file)

    num_atributos, num_clases = split(file_lines[1], " ")
    num_atributos, num_clases = parse(Int64, num_atributos), parse(Int64, num_clases)
    adaline = crear_adaline(num_atributos, num_clases)

    fin_entrenamiento = true
    for _ in 1:max_epocas
        # Reset flag
        fin_entrenamiento = true
        for line in file_lines[2:size(file_lines,1)]
            valores = map((x) -> parse(Float64, x), split(line, "  "))  # TODO: fix double spaces
            
            avanzar_ciclo(adaline, valores[1:num_atributos])

            atributos = [valores[1:num_atributos]; [1]]
            clases = valores[num_atributos+1:size(valores,1)]
            fin_entrenamiento = fin_entrenamiento & entrenamiento_adaline(adaline, tasa_aprendizaje, num_atributos+1, atributos, num_clases, clases, tolerancia)

            print_pesos(adaline)
        end

        if fin_entrenamiento
            println("Entrenamiento finalizado por convergencia en los pesos.")
            break
        end

    end

    if !fin_entrenamiento
        println("Entrenamiento finalizado: número máximo de épocas alcanzado.")
    end
    
    RedNeuronal_pkg.Liberar(adaline)

end

main()