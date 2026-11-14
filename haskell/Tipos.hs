-- Tipos.hs
-- Tipos de Datos Algebraicos (ADTs) para la Capacidad C1 (Integrar la evidencia).
-- Todo este modulo es 100% puro y usa unicamente tipos estandar de Haskell.

module Tipos where

-- Módulos de la estación Halley-7 según estacion.csv
data Modulo
  = COM
  | DOR
  | LAB_A
  | LAB_B
  | GEN
  | RAD
  | ALM
  | EXT
  | TODOS
  deriving (Eq, Ord, Show)

-- Convierte el tipo algebraico Modulo al texto exacto del JSON
moduloATexto :: Modulo -> String
moduloATexto m = case m of
  COM   -> "COM"
  DOR   -> "DOR"
  LAB_A -> "LAB-A"
  LAB_B -> "LAB-B"
  GEN   -> "GEN"
  RAD   -> "RAD"
  ALM   -> "ALM"
  EXT   -> "EXT"
  TODOS -> "*"

-- Las 6 fuentes de evidencia de la estación
data Fuente
  = FuenteTarjetas
  | FuenteRadio
  | FuenteEnergia
  | FuentePresencia
  | FuenteTemperatura
  | FuenteBitacora
  deriving (Eq, Ord, Show)

-- Nombre del archivo para el campo "fuente" del JSON
fuenteATexto :: Fuente -> String
fuenteATexto f = case f of
  FuenteTarjetas    -> "tarjetas.csv"
  FuenteRadio       -> "radio.txt"
  FuenteEnergia     -> "energia.json"
  FuentePresencia   -> "presencia.csv"
  FuenteTemperatura -> "temperatura.csv"
  FuenteBitacora    -> "bitacora.txt"

-- Prefijo para generar el campo "id" (ej. "tarjetas-00001")
prefijoFuente :: Fuente -> String
prefijoFuente f = case f of
  FuenteTarjetas    -> "tarjetas"
  FuenteRadio       -> "radio"
  FuenteEnergia     -> "energia"
  FuentePresencia   -> "presencia"
  FuenteTemperatura -> "temperatura"
  FuenteBitacora    -> "bitacora"

-- Estado de validación de cada registro (ningún dato se descarta)
data Estado
  = Valido
  | Denegado
  | Duplicado
  | Corrupto
  | Contradictorio
  deriving (Eq, Ord, Show)

estadoATexto :: Estado -> String
estadoATexto e = case e of
  Valido         -> "valido"
  Denegado       -> "denegado"
  Duplicado      -> "duplicado"
  Corrupto       -> "corrupto"
  Contradictorio -> "contradictorio"

-- Registro de referencia de personal.csv
data PersonaRef = PersonaRef
  { refTarjeta :: String,
    refNombre  :: String,
    refCargo   :: String,
    refAccesos :: [String]
  }
  deriving (Eq, Show)

-- Registro de referencia de estacion.csv
data PuertaRef = PuertaRef
  { refPuerta      :: String,
    refModulo1     :: Modulo,
    refModulo2     :: Modulo,
    refTieneLector :: Bool
  }
  deriving (Eq, Show)

-- Estructura canónica de un evento integrado.
-- Contiene exactamente los 14 campos acordados por el equipo para el JSON.
data Evento = Evento
  { evId            :: String,
    evFuente        :: Fuente,
    evLineaOriginal :: Int,
    evTipo          :: String,
    evTsOriginal    :: Maybe String,
    evTsUtc         :: Maybe String,
    evPersona       :: Maybe String,
    evModulo        :: Maybe Modulo,
    evPuerta        :: Maybe String,
    evDesde         :: Maybe Modulo,
    evHacia         :: Maybe Modulo,
    evValor         :: Maybe Double,
    evEstado        :: Estado,
    evMotivo        :: Maybe String
  }
  deriving (Eq, Show)
