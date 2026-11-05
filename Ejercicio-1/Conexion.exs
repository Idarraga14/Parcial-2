defmodule Conexion do
  @enforce_keys [:origen, :destino, :distancia]
  defstruct [:origen, :destino, :distancia]

  def parse(linea) do
    linea_limpia = String.trim(linea)

    cond do
      linea_limpia == "" or String.starts_with?(linea_limpia, "#") ->
        :ignorar

      true ->
        case String.split(linea_limpia, ",") do
          [origen, destino, distancia_str] ->
            orig = String.trim(origen)
            dest = String.trim(destino)
            dist_s = String.trim(distancia_str)

            if orig == "" or dest == "" do
              {:error, "Campos de ciudad vacíos"}
            else
              case Integer.parse(dist_s) do
                {dist, ""} when dist >= 0 ->
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
