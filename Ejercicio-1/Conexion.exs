defmodule Conexion do
@enforce_keys [:origen,:destino,:distancia]
defstruct [:origen,:destino,:distancia]

def parse(linea) do
  linea_limpia=String.trim(linea)
  if linea_limpia == "" or String.starts_with?(linea_limpia, "#") do
    :ignorar
  else 
  end
end
end
