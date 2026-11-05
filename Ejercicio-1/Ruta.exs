defmodule Ruta do
  @enforce_keys [:ciudades, :distancia]
  defstruct [:ciudades, :distancia]

  # Recibe un struct y extrae las variables ciudades y distancia, ademas del identificador de la ruta
  def a_texto(%Ruta{ciudades: ciudades, distancia: dist}, numero) do
    cant_ciudades = contar_rec(ciudades, 0)
    recorrido = unir_ciudades_rec(ciudades, " -> ")
    # Retorna un string
    "Ruta #{numero}: #{recorrido} (#{cant_ciudades} ciudades, #{dist} km)"
  end

  # Caso base si la lista es vacia devuelve el acumulador
  defp contar_rec([], acc), do: acc
  # Toma la cola y la pasa al siguiente sumando 1 al acumulador
  defp contar_rec([_ | t], acc), do: contar_rec(t, acc + 1)

  # Caso base de la union, cuando es la ultima ciudad solo la devuelve no le añade otro separador
  defp unir_ciudades_rec([h], _sep), do: h
  # Concatena el nombre de la ciudad y le añade el separador
  defp unir_ciudades_rec([h | t], sep), do: h <> sep <> unir_ciudades_rec(t, sep)
end
