defmodule Conexion do
  # Obligatorio especificar origen destino y distancia
  @enforce_keys [:origen, :destino, :distancia]
  defstruct [:origen, :destino, :distancia]

  def parse(linea) do
    linea_limpia = String.trim(linea)

    cond do
      # Si empieza por # o está vacia retorna ignorar
      linea_limpia == "" or String.starts_with?(linea_limpia, "#") ->
        :ignorar

      true ->
        # Lista de cadena separadas por comas
        case String.split(linea_limpia, ",") do
          # Desestructura en 3 variables a,b,c
          [origen, destino, distancia_str] ->
            #
            orig = String.trim(origen)
            # Limpia los espacios extremos
            dest = String.trim(destino)
            #
            dist_s = String.trim(distancia_str)

            if orig == "" or dest == "" do
              # Manejo de errores cuando en la linea hay origen y destino vacios
              {:error, "Campos de ciudad vacíos"}
            else
              case Integer.parse(dist_s) do
                # Conversion y devolucion del mapa
                {dist, ""} when dist >= 0 ->
                  {:ok, %Conexion{origen: orig, destino: dest, distancia: dist}}

                _ ->
                  {:error, "Distancia no numérica o negativa: '#{dist_s}'"}
              end
            end

          # Si la lista no tiene 3 elementos el error se maneja por faltantes o por adicionales
          partes ->
            num_partes = length(partes)

            if num_partes < 3 do
              {:error, "Campos faltantes (se esperaban 3, se encontraron #{num_partes})"}
            else
              {:error, "Campos adicionales no esperados (se encontraron #{num_partes})"}
            end
        end
    end
  end
end
