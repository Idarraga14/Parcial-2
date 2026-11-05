defmodule Conexion do
  @enforce_keys [:origen, :destino, :distancia] #Obligatorio especificar origen destino y distancia
  defstruct [:origen, :destino, :distancia]

  def parse(linea) do
    linea_limpia = String.trim(linea)

    cond do
      linea_limpia == "" or String.starts_with?(linea_limpia, "#") -> #Si empieza por # o está vacia retorna ignorar
        :ignorar

      true ->
        case String.split(linea_limpia, ",") do
          [origen, destino, distancia_str] ->      #Desestructura en 3 variables a,b,c
            orig = String.trim(origen)             #
            dest = String.trim(destino)            #Limpia los espacios extremos
            dist_s = String.trim(distancia_str)    #

            if orig == "" or dest == "" do
              {:error, "Campos de ciudad vacíos"} #Manejo de errores cuando en la linea hay origen y destino vacios
            else
              case Integer.parse(dist_s) do
                {dist, ""} when dist >= 0 ->      #Conversion y devolucion del mapa
                  {:ok, %Conexion{origen: orig, destino: dest, distancia: dist}}

                _ ->
                  {:error, "Distancia no numérica o negativa: '#{dist_s}'"}
              end
            end

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
