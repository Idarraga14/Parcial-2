defmodule RutasCiudades do
  # Definiciion de constantes
  @archivo_conexiones "conexiones.csv"
  @archivo_consultas "consultas.txt"
  @archivo_errores "errores_conexiones.txt"
  @archivo_depuracion "depuracion_conexiones.txt"
  @archivo_alcance "alcance.txt"
  @archivo_salida "rutas_encontradas.txt"

  def ejecutar do
    # Control de errores 1 y dos sino iniciar el proceso
    unless File.exists?(@archivo_conexiones) do
      IO.puts("Error: El archivo de entrada '#{@archivo_conexiones}' no existe.")
    else
      unless File.exists?(@archivo_consultas) do
        IO.puts("Error: El archivo de entrada '#{@archivo_consultas}' no existe.")
      else
        procesar_sistema()
      end
    end
  end

  defp procesar_sistema do
    # Lectura con stream
    lineas_stream =
      @archivo_conexiones
      |> File.stream!()
      |> Stream.with_index(1)
      |> Stream.map(fn {linea, num_linea} ->
        {num_linea, linea, Conexion.parse(linea)}
      end)
      |> Stream.filter(fn {_num, _linea, res} -> res != :ignorar end)

    {validas_raw, errores} = separar_lineas(lineas_stream)
    escribir_lineas(@archivo_errores, errores)

    # Validacion previa con recursion
    {conexiones_depuradas, reportes_depuracion} = depurar_conexiones_rec(validas_raw, %{}, [], [])
    escribir_lineas(@archivo_depuracion, reportes_depuracion)

    # Construccion del grafo
    grafo = construir_grafo_rec(conexiones_depuradas, %{})

    # Consultas
    procesar_consultas(grafo)
  end

  # SEPARACIÓN DE ERRORES DE SINTAXIS
  defp separar_lineas(stream) do
    Enum.reduce(stream, {[], []}, fn
      {num, linea, {:ok, conexion}}, {val, err} ->
        {val ++ [{num, linea, conexion}], err}

      {num, linea, {:error, motivo}}, {val, err} ->
        msg = "Línea #{num}: #{String.trim(linea)} -> #{motivo}"
        {val, err ++ [msg]}
    end)
  end

  # VALIDACIÓN PREVIA CON RECURSION
  defp depurar_conexiones_rec([], _vistos, validas_acc, reportes_acc) do
    {revertir_rec(validas_acc, []), revertir_rec(reportes_acc, [])}
  end

  defp depurar_conexiones_rec([{num, raw, conexion} | tail], vistos, validas_acc, reportes_acc) do
    %Conexion{origen: o, destino: d, distancia: dist} = conexion
    linea_str = String.trim(raw)

    cond do
      # Conexión consigo misma
      o == d ->
        rep = "Línea #{num}: #{linea_str} -> conecta una ciudad consigo misma; se descarta"
        depurar_conexiones_rec(tail, vistos, validas_acc, [rep | reportes_acc])

      true ->
        clave = if(o < d, do: {o, d}, else: {d, o})

        case Map.get(vistos, clave) do
          nil ->
            nuevos_vistos = Map.put(vistos, clave, {dist, num})
            depurar_conexiones_rec(tail, nuevos_vistos, [conexion | validas_acc], reportes_acc)

          {prev_dist, prev_num} ->
            if dist == prev_dist do
              rep = "Línea #{num}: #{linea_str} -> repetida (línea #{prev_num}); se descarta"
              depurar_conexiones_rec(tail, vistos, validas_acc, [rep | reportes_acc])
            else
              rep =
                "Línea #{num}: #{linea_str} -> distancia distinta a la de la línea #{prev_num} (#{prev_dist}); se conserva la de la línea #{prev_num}"

              depurar_conexiones_rec(tail, vistos, validas_acc, [rep | reportes_acc])
            end
        end
    end
  end

  # CONSTRUCCIÓN RECURSIVA DEL GRAFO
  defp construir_grafo_rec([], grafo), do: grafo

  defp construir_grafo_rec([%Conexion{origen: o, destino: d, distancia: dist} | tail], grafo) do
    g1 = agregar_arista(grafo, o, d, dist)
    g2 = agregar_arista(g1, d, o, dist)
    construir_grafo_rec(tail, g2)
  end

  defp agregar_arista(grafo, desde, hacia, dist) do
    vecinos = Map.get(grafo, desde, [])
    Map.put(grafo, desde, [{hacia, dist} | vecinos])
  end

  # STREAMS INFINITOS: CIUDADES ALCANZABLES
  defp stream_alcanzables(grafo, origen) do
    Stream.iterate(MapSet.new([origen]), fn conjunto_actual ->
      Enum.reduce(conjunto_actual, conjunto_actual, fn ciudad, acc ->
        vecinos = Map.get(grafo, ciudad, [])
        Enum.reduce(vecinos, acc, fn {v, _d}, acc_v -> MapSet.put(acc_v, v) end)
      end)
    end)
  end

  defp calcular_alcance_estabilizado(grafo, origen) do
    stream_alcanzables(grafo, origen)
    |> Stream.with_index()
    |> Enum.reduce_while({[], nil}, fn {conjunto, paso}, {pasos_acc, prev_conjunto} ->
      ciudades_str = conjunto |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")
      paso_linea = "Paso #{paso}: #{ciudades_str}"

      if prev_conjunto != nil and conjunto == prev_conjunto do
        paso_estab = "Se estabiliza en el paso #{paso - 1}"
        {:halt, {Enum.reverse([paso_estab | pasos_acc]), prev_conjunto}}
      else
        {:cont, {[paso_linea | pasos_acc], conjunto}}
      end
    end)
  end

  # BÚSQUEDA RECURSIVA DE RUTAS
  def buscar_rutas(grafo, origen, destino) do
    buscar_rutas_rec(grafo, origen, destino, [origen], 0)
  end

  defp buscar_rutas_rec(_grafo, destino, destino, camino_rev, dist_acum) do
    [%Ruta{ciudades: revertir_rec(camino_rev, []), distancia: dist_acum}]
  end

  defp buscar_rutas_rec(grafo, actual, destino, camino_rev, dist_acum) do
    vecinos = Map.get(grafo, actual, [])
    explorar_vecinos_rec(vecinos, grafo, destino, camino_rev, dist_acum, [])
  end

  defp explorar_vecinos_rec([], _grafo, _destino, _camino_rev, _dist_acum, rutas_acc),
    do: rutas_acc

  defp explorar_vecinos_rec(
         [{vecino, dist} | resto],
         grafo,
         destino,
         camino_rev,
         dist_acum,
         rutas_acc
       ) do
    if contiene_rec?(camino_rev, vecino) do
      explorar_vecinos_rec(resto, grafo, destino, camino_rev, dist_acum, rutas_acc)
    else
      rutas_desde_vecino =
        buscar_rutas_rec(grafo, vecino, destino, [vecino | camino_rev], dist_acum + dist)

      nuevas_rutas = concatenar_rec(rutas_acc, rutas_desde_vecino)
      explorar_vecinos_rec(resto, grafo, destino, camino_rev, dist_acum, nuevas_rutas)
    end
  end

  # ATENCIÓN DE CONSULTAS Y GENERACIÓN DE SALIDAS
  defp procesar_consultas(grafo) do
    file_salida = File.open!(@archivo_salida, [:write, :utf8])
    file_alcance = File.open!(@archivo_alcance, [:write, :utf8])

    @archivo_consultas
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(fn l -> l == "" or String.starts_with?(l, "#") end)
    |> Enum.each(fn linea_consulta ->
      case String.split(linea_consulta, ",") do
        [orig_raw, dest_raw] ->
          origen = String.trim(orig_raw)
          destino = String.trim(dest_raw)
          resolver_consulta(grafo, origen, destino, file_salida, file_alcance)

        _ ->
          :ok
      end
    end)

    File.close(file_salida)
    File.close(file_alcance)
  end

  defp resolver_consulta(grafo, origen, destino, file_salida, file_alcance) do
    ciudades_existentes = Map.keys(grafo)

    cond do
      not contiene_rec?(ciudades_existentes, origen) ->
        encabezado = "=== #{origen} -> #{destino} ==="
        imprimir_y_escribir(encabezado, file_salida)

        imprimir_y_escribir(
          "La ciudad de origen '#{origen}' no existe en el grafo.\n",
          file_salida
        )

      not contiene_rec?(ciudades_existentes, destino) ->
        encabezado = "=== #{origen} -> #{destino} ==="
        imprimir_y_escribir(encabezado, file_salida)

        imprimir_y_escribir(
          "La ciudad de destino '#{destino}' no existe en el grafo.\n",
          file_salida
        )

      true ->
        # Calculo de conjunto de alcance con Stream Infinito
        {lineas_alcance, conjunto_final} = calcular_alcance_estabilizado(grafo, origen)

        IO.puts(file_alcance, "=== Alcance desde #{origen} ===")
        Enum.each(lineas_alcance, &IO.puts(file_alcance, &1))
        IO.puts(file_alcance, "")

        encabezado = "=== #{origen} -> #{destino} ==="
        imprimir_y_escribir(encabezado, file_salida)

        # Verificar si el destino esta en el alcance
        if not MapSet.member?(conjunto_final, destino) do
          imprimir_y_escribir(
            "Sin rutas (El destino '#{destino}' no es alcanzable desde '#{origen}').\n",
            file_salida
          )
        else
          rutas = buscar_rutas(grafo, origen, destino)
          imprimir_rutas_rec(rutas, 1, file_salida)

          total_rutas = contar_rec(rutas, 0)
          imprimir_y_escribir("Número de rutas: #{total_rutas}", file_salida)

          mas_corta = obtener_mas_corta_rec(rutas)
          menor_dist = obtener_menor_distancia_rec(rutas)

          imprimir_y_escribir(
            "Ruta más corta: #{unir_ciudades_rec(mas_corta.ciudades, " -> ")}",
            file_salida
          )

          imprimir_y_escribir(
            "Ruta de menor distancia: #{unir_ciudades_rec(menor_dist.ciudades, " -> ")} (#{menor_dist.distancia} km)\n",
            file_salida
          )
        end
    end
  end

  defp imprimir_rutas_rec([], _num, _file), do: :ok

  defp imprimir_rutas_rec([ruta | tail], num, file) do
    imprimir_y_escribir(Ruta.a_texto(ruta, num), file)
    imprimir_rutas_rec(tail, num + 1, file)
  end

  defp imprimir_y_escribir(texto, file) do
    IO.puts(texto)
    IO.puts(file, texto)
  end

  defp escribir_lineas(ruta_archivo, lineas) do
    contenido = Enum.join(lineas, "\n") <> if(lineas == [], do: "", else: "\n")
    File.write!(ruta_archivo, contenido)
  end

  # FUNCIONES AUXILIARES RECURSIVAS PURAS
  defp contiene_rec?([], _elem), do: false
  defp contiene_rec?([h | _t], elem) when h == elem, do: true
  defp contiene_rec?([_h | t], elem), do: contiene_rec?(t, elem)

  defp revertir_rec([], acc), do: acc
  defp revertir_rec([h | t], acc), do: revertir_rec(t, [h | acc])

  defp concatenar_rec([], l2), do: l2
  defp concatenar_rec([h | t], l2), do: [h | concatenar_rec(t, l2)]

  defp contar_rec([], acc), do: acc
  defp contar_rec([_ | t], acc), do: contar_rec(t, acc + 1)

  defp unir_ciudades_rec([h], _sep), do: h
  defp unir_ciudades_rec([h | t], sep), do: h <> sep <> unir_ciudades_rec(t, sep)

  defp obtener_mas_corta_rec([primera | resto]), do: evaluar_mas_corta_rec(resto, primera)
  defp evaluar_mas_corta_rec([], mejor), do: mejor

  defp evaluar_mas_corta_rec([actual | resto], mejor) do
    if contar_rec(actual.ciudades, 0) < contar_rec(mejor.ciudades, 0) do
      evaluar_mas_corta_rec(resto, actual)
    else
      evaluar_mas_corta_rec(resto, mejor)
    end
  end

  defp obtener_menor_distancia_rec([primera | resto]),
    do: evaluar_menor_distancia_rec(resto, primera)

  defp evaluar_menor_distancia_rec([], mejor), do: mejor

  defp evaluar_menor_distancia_rec([actual | resto], mejor) do
    if actual.distancia < mejor.distancia do
      evaluar_menor_distancia_rec(resto, actual)
    else
      evaluar_menor_distancia_rec(resto, mejor)
    end
  end
end

RutasCiudades.ejecutar()
