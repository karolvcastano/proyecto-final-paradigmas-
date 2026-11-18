-- Main.hs
-- Unico modulo con efectos de entrada/salida (IO) en los bordes.
-- Se ejecuta directamente con: runghc Main.hs
-- O pasandole una carpeta con los 8 archivos: runghc Main.hs ./ruta_datos
-- O una carpeta y un archivo de salida: runghc Main.hs ./ruta_datos salida.json

module Main where

import DatosAnexoA
import Json (eventosAJson)
import System.Directory (doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import Tipos (Evento)
import Validador (integrarEvidencia)

main :: IO ()
main = do
  args <- getArgs
  case args of
    -- Sin argumentos: integra los datos del Anexo A e imprime el JSON por consola
    [] -> putStr (eventosAJson integrarAnexoA)

    -- Con carpeta de entrada: lee los 8 archivos de esa carpeta e imprime el JSON
    [carpeta] -> do
      resultado <- leerEIntegrarCarpeta carpeta
      case resultado of
        Left err   -> putStrLn ("Error: " ++ err) >> exitFailure
        Right evs  -> putStr (eventosAJson evs)

    -- Con carpeta de entrada y archivo de salida: guarda el JSON en disco
    [carpeta, archivoSalida] -> do
      resultado <- leerEIntegrarCarpeta carpeta
      case resultado of
        Left err   -> putStrLn ("Error: " ++ err) >> exitFailure
        Right evs  -> writeFile archivoSalida (eventosAJson evs)

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

-- Lee los 8 archivos desde una carpeta (IO) y se los entrega al nucleo puro.
-- Si falta un archivo, devuelve un error legible en lugar de terminar con
-- una excepcion sin contexto.
leerEIntegrarCarpeta :: FilePath -> IO (Either String [Evento])
leerEIntegrarCarpeta dir = do
  resultados <- mapM (leerArchivo . rutaEn dir) archivosEsperados
  case sequence resultados of
    Left err -> return (Left err)
    Right [txtPersonal, txtEstacion, txtTarjetas, txtRadio, txtEnergia, txtPresencia, txtTemp, txtBitacora] ->
      return
        ( Right
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
        )
    Right _ -> return (Left "Error interno: se esperaban exactamente 8 archivos")

rutaEn :: FilePath -> FilePath -> FilePath
rutaEn dir archivo = dir ++ "/" ++ archivo

archivosEsperados :: [FilePath]
archivosEsperados =
  [ "personal.csv",
    "estacion.csv",
    "tarjetas.csv",
    "radio.txt",
    "energia.json",
    "presencia.csv",
    "temperatura.csv",
    "bitacora.txt"
  ]

leerArchivo :: FilePath -> IO (Either String String)
leerArchivo ruta = do
  existe <- doesFileExist ruta
  if not existe
    then return (Left ("No existe el archivo: " ++ ruta))
    else do
      contenido <- readFile ruta
      return (Right contenido)
