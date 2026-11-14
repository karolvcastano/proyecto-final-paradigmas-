-- Main.hs
-- Unico modulo con efectos de entrada/salida (IO) en los bordes.
-- Se ejecuta directamente con: runghc Main.hs
-- O pasandole una carpeta con los 8 archivos: runghc Main.hs ./ruta_datos

module Main where

import DatosAnexoA
import Json (eventosAJson)
import System.Environment (getArgs)
import Tipos (Evento)
import Validador (integrarEvidencia)

main :: IO ()
main = do
  args <- getArgs
  case args of
    -- Sin argumentos: integra los datos del Anexo A e imprime el JSON por consola
    [] -> do
      let eventos = integrarAnexoA
      putStr (eventosAJson eventos)

    -- Con carpeta de entrada: lee los 8 archivos de esa carpeta e imprime el JSON
    [carpeta] -> do
      eventos <- leerEIntegrarCarpeta carpeta
      putStr (eventosAJson eventos)

    -- Con carpeta de entrada y archivo de salida: guarda el JSON en disco
    [carpeta, archivoSalida] -> do
      eventos <- leerEIntegrarCarpeta carpeta
      writeFile archivoSalida (eventosAJson eventos)

    _ ->
      putStrLn "Uso: runghc Main.hs [carpeta_datos] [archivo_salida.json]"

-- Invoca la funcion pura integrarEvidencia con las 8 cadenas del Anexo A
integrarAnexoA :: [Evento]
integrarAnexoA =
  integrarEvidencia
    personalAnexoA
    estacionAnexoA
    tarjetasAnexoA
    radioAnexoA
    energiaAnexoA
    presenciaAnexoA
    temperaturaAnexoA
    bitacoraAnexoA

-- Lee los 8 archivos desde una carpeta (IO) y se los entrega al nucleo puro
leerEIntegrarCarpeta :: FilePath -> IO [Evento]
leerEIntegrarCarpeta dir = do
  txtPersonal  <- readFile (dir ++ "/personal.csv")
  txtEstacion  <- readFile (dir ++ "/estacion.csv")
  txtTarjetas  <- readFile (dir ++ "/tarjetas.csv")
  txtRadio     <- readFile (dir ++ "/radio.txt")
  txtEnergia   <- readFile (dir ++ "/energia.json")
  txtPresencia <- readFile (dir ++ "/presencia.csv")
  txtTemp      <- readFile (dir ++ "/temperatura.csv")
  txtBitacora  <- readFile (dir ++ "/bitacora.txt")
  return
    ( integrarEvidencia
        txtPersonal
        txtEstacion
        txtTarjetas
        txtRadio
        txtEnergia
        txtPresencia
        txtTemp
        txtBitacora
    )
