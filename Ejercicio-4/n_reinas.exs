defmodule NReinas do
  @moduledoc """
  Solución al Problema 4: N Reinas (Búsqueda perezosa, verificación recursiva y streams infinitos).
  Programación III - Universidad del Quindío.
  """

  def main do
    IO.puts("=== INICIANDO PROCESAMIENTO DE TAMAÑOS (N REINAS) ===")
    procesar_tamanos("tamanos.txt", "errores_tamanos.txt")

    IO.puts("\n=== INICIANDO VERIFICACIÓN DE PROPUESTAS ===")
    verificar_propuestas("propuestas.txt", "verificacion_reinas.txt")

    IO.puts("\n=== GENERANDO SECUENCIA INFINITA (STREAMS) ===")
    generar_secuencia_infinita("secuencia_reinas.csv")

    IO.puts("\n¡Proceso del Parcial completado con éxito!")
  end

  # ====================================================================
  # PARTE 1: PROCESAMIENTO DE TAMAÑOS Y BÚSQUEDA PEREZOSA
  # ====================================================================

  def procesar_tamanos(ruta_tamanos \\ "tamanos.txt", ruta_errores \\ "errores_tamanos.txt") do
    case File.exists?(ruta_tamanos) do
      false ->
        IO.puts("El archivo #{ruta_tamanos} no existe.")
      true ->
        io_errores = File.open!(ruta_errores, [:write, :utf8])

        File.stream!(ruta_tamanos)
        |> Stream.with_index(1)
        |> Enum.each(fn {linea, num_linea} ->
          linea_limpia = String.trim(linea)
          cond do
            linea_limpia == "" or String.starts_with?(linea_limpia, "#") ->
              :ok
            true ->
              case validar_entero_positivo(linea_limpia) do
                {:ok, n} ->
                  IO.puts("Procesando N = #{n}...")
                  if n == 20 do
                    resolver_n20()
                  else
                    resolver_y_guardar(n)
                  end
                {:error, motivo} ->
                  IO.write(io_errores, "#{num_linea}: #{linea_limpia} -> #{motivo}\n")
              end
          end
        end)

        File.close(io_errores)
        IO.puts("Proceso de tamaños finalizado. Errores registrados en #{ruta_errores}.")
    end
  end

  defp validar_entero_positivo(str) do
    case Integer.parse(str) do
      {n, ""} when n > 0 -> {:ok, n}
      {_, ""} -> {:error, "No es un entero positivo (debe ser mayor a 0)"}
      _ -> {:error, "Contenido no numérico o inválido"}
    end
  end

  # Búsqueda perezosa implementada mediante Stream.resource
  def resolver_n(n) do
    Stream.resource(
      fn -> {[[]], n} end,
      fn
        {[], _n} -> {:halt, nil}
        {parciales, n} ->
          case encontrar_siguiente_solucion(parciales, n) do
            {solucion, nuevos_parciales} -> {[solucion], {nuevos_parciales, n}}
            :fin -> {:halt, nil}
          end
      end,
      fn _ -> :ok end
    )
  end

  defp encontrar_siguiente_solucion([], _n), do: :fin
  defp encontrar_siguiente_solucion([tablero | resto], n) do
    fila_actual = length(tablero)
    if fila_actual == n do
      {tablero, resto}
    else
      nuevos_parciales =
        for col <- 0..(n - 1),
            es_valido?(col, tablero),
            reduce: resto do
          acc -> [[col | tablero] | acc]
        end
      encontrar_siguiente_solucion(nuevos_parciales, n)
    end
  end

  defp es_valido?(col, tablero) do
    validar_conflicto(col, tablero, 0)
  end

  defp validar_conflicto(_col, [], _fila_reina), do: true
  defp validar_conflicto(col, [col_existente | resto], fila_reina) do
    if col == col_existente or abs(col - col_existente) == (fila_reina + 1) do
      false
    else
      validar_conflicto(col, resto, fila_reina + 1)
    end
  end

  # Escritura progresiva línea por línea en reinas_n<N>.txt
  defp resolver_y_guardar(n) do
    ruta_salida = "reinas_n#{n}.txt"
    io_out = File.open!(ruta_salida, [:write, :utf8])

    {total, _} =
      resolver_n(n)
      |> Stream.with_index(1)
      |> Enum.reduce({0, io_out}, fn {solucion, idx}, {count, io} ->
        IO.write(io, "Solución #{idx}:\n")
        escribir_tablero(io, solucion, n)
        IO.write(io, "\n")
        {count + 1, io}
      end)

    IO.write(io_out, "Número total de soluciones: #{total}\n")
    File.close(io_out)
  end

  defp escribir_tablero(io, solucion, n) do
    solucion
    |> Enum.reverse()
    |> Enum.each(fn col ->
      linea =
        for c <- 0..(n - 1) do
          if c == col, do: "Q", else: "."
        end
        |> Enum.join(" ")
      IO.write(io, "#{linea}\n")
    end)
  end

  # Caso N = 20: obtiene únicamente la primera solución sin evaluar el espacio masivo
  defp resolver_n20 do
    ruta_n20 = "primera_solucion_n20.txt"
    io = File.open!(ruta_n20, [:write, :utf8])

    primera =
      resolver_n(20)
      |> Enum.take(1)

    case primera do
      [solucion] ->
        IO.write(io, "Primera solución para N = 20:\n")
        escribir_tablero(io, solucion, 20)
        IO.puts("¡Primera solución para N = 20 encontrada y guardada en #{ruta_n20}!")
      _ ->
        IO.write(io, "No se encontró solución para N = 20.\n")
    end

    File.close(io)
  end

  # ====================================================================
  # PARTE 2: VERIFICACIÓN RECURSIVA PROPIA DE PROPUESTAS
  # ====================================================================

  def verificar_propuestas(ruta_propuestas \\ "propuestas.txt", ruta_verificacion \\ "verificacion_reinas.txt") do
    case File.exists?(ruta_propuestas) do
      false ->
        IO.puts("El archivo #{ruta_propuestas} no existe.")
      true ->
        io_out = File.open!(ruta_verificacion, [:write, :utf8])

        File.stream!(ruta_propuestas)
        |> Stream.map(&String.trim/1)
        |> Stream.reject(fn linea -> linea == "" or String.starts_with?(linea, "#") end)
        |> Enum.each(fn linea ->
          resultado = analizar_propuesta(linea)
          IO.write(io_out, "#{linea} -> #{resultado}\n")
        end)

        File.close(io_out)
        IO.puts("Verificación de propuestas finalizada. Resultados en #{ruta_verificacion}.")
    end
  end

  defp analizar_propuesta(linea) do
    case convertir_a_lista_recursiva(linea, "", []) do
      {:ok, columnas} ->
        n = longitud_recursiva(columnas)
        cond do
          contiene_fuera_de_rango?(columnas, 0, n) ->
            col_invalida = encontrar_fuera_de_rango(columnas, 0, n)
            "inválida: la columna #{col_invalida} está fuera de un tablero de #{n} × #{n}"
          true ->
            conflictos = hallar_conflictos(columnas, 0)
            if longitud_recursiva(conflictos) == 0 do
              "válida"
            else
              "inválida: " <> formatear_conflictos(conflictos)
            end
        end
      {:error, motivo} ->
        "inválida: #{motivo}"
    end
  end

  # Conversión robusta con validación estricta de dígitos (evita aceptar letras como 'x')
  defp convertir_a_lista_recursiva("", "", acc), do: {:ok, invertir_recursivo(acc, [])}
  defp convertir_a_lista_recursiva("", numero_actual, acc) do
    case string_a_entero_recursivo(numero_actual, 0) do
      {:ok, val} -> {:ok, invertir_recursivo([val | acc], [])}
      {:error, razon} -> {:error, razon}
    end
  end
  defp convertir_a_lista_recursiva(<<char::utf8, resto::binary>>, numero_actual, acc) do
    cond do
      char == ?\s or char == ?\t ->
        if numero_actual == "" do
          convertir_a_lista_recursiva(resto, "", acc)
        else
          case string_a_entero_recursivo(numero_actual, 0) do
            {:ok, val} -> convertir_a_lista_recursiva(resto, "", [val | acc])
            {:error, razon} -> {:error, razon}
          end
        end
      true ->
        convertir_a_lista_recursiva(resto, numero_actual <> <<char::utf8>>, acc)
    end
  end

  defp string_a_entero_recursivo(<<char::utf8, resto::binary>>, acumulado) do
    if char >= ?0 and char <= ?9 do
      digito = char - ?0
      string_a_entero_recursivo(resto, acumulado * 10 + digito)
    else
      {:error, "contiene caracteres no numéricos inválidos"}
    end
  end
  defp string_a_entero_recursivo("", acumulado), do: {:ok, acumulado}

  defp invertir_recursivo([], acc), do: acc
  defp invertir_recursivo([h | t], acc), do: invertir_recursivo(t, [h | acc])

  defp longitud_recursiva([]), do: 0
  defp longitud_recursiva([_ | t]), do: 1 + longitud_recursiva(t)

  defp contiene_fuera_de_rango?([], _fila, _n), do: false
  defp contiene_fuera_de_rango?([c | t], fila, n) do
    if c < 0 or c >= n do
      true
    else
      contiene_fuera_de_rango?(t, fila + 1, n)
    end
  end

  defp encontrar_fuera_de_rango([c | _t], _fila, n) when c < 0 or c >= n, do: c
  defp encontrar_fuera_de_rango([_c | t], fila, n), do: encontrar_fuera_de_rango(t, fila + 1, n)

  defp hallar_conflictos([], _fila), do: []
  defp hallar_conflictos([c1 | resto], fila1) do
    verificar_con_siguientes(fila1, c1, resto, fila1 + 1) ++ hallar_conflictos(resto, fila1 + 1)
  end

  defp verificar_con_siguientes(_fila1, _c1, [], _fila2), do: []
  defp verificar_con_siguientes(fila1, c1, [c2 | resto], fila2) do
    conflictos_actuales =
      cond do
        c1 == c2 ->
          [{fila1, c1, fila2, c2, :columna}]
        abs(fila1 - fila2) == abs(c1 - c2) ->
          [{fila1, c1, fila2, c2, :diagonal}]
        true ->
          []
      end
    conflictos_actuales ++ verificar_con_siguientes(fila1, c1, resto, fila2 + 1)
  end

  defp formatear_conflictos([]), do: ""
  defp formatear_conflictos([conf | resto]) do
    mensaje =
      case conf do
        {r1, c1, r2, c2, :columna} ->
          "reinas {#{r1},#{c1}} y {#{r2},#{c2}} en la misma columna"
        {r1, c1, r2, c2, :diagonal} ->
          "reinas {#{r1},#{c1}} y {#{r2},#{c2}} en la misma diagonal"
      end

    resto_formateado = formatear_conflictos(resto)
    if resto_formateado == "" do
      mensaje
    else
      mensaje <> "; " <> resto_formateado
    end
  end

  # ====================================================================
  # PARTE 3: STREAM INFINITO Y MEDICIÓN DE TIEMPOS (SECUENCIA_REINAS.CSV)
  # ====================================================================

  @limite_ms 10_000

  def generar_secuencia_infinita(ruta_csv \\ "secuencia_reinas.csv") do
    io = File.open!(ruta_csv, [:write, :utf8])
    IO.write(io, "n;soluciones;tiempo_ms\n")

    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn n ->
      {us, sol} = :timer.tc(fn -> n |> resolver_n() |> Enum.count() end)
      IO.puts("N = #{n} -> #{sol} soluciones, #{us / 1000} ms")
      {n, sol, us / 1000}
    end)
    |> Stream.take_while(fn {_n, _sol, ms} -> ms < @limite_ms end)
    |> Stream.each(fn {n, sol, ms} -> IO.write(io, "#{n};#{sol};#{ms}\n") end)
    |> Stream.run()

    File.close(io)
    IO.puts("Secuencia guardada en #{ruta_csv}.")
  end
end

NReinas.main()
