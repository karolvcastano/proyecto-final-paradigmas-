-- Pruebas.hs
-- Pruebas automaticas de las funciones puras de C1.
-- Se ejecuta directamente con: runghc Pruebas.hs

module Main where

import Data.List (isInfixOf)
import DatosAnexoA
import Normalizar
import Parsers
import Tipos
import Validador (integrarEvidencia)

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

personasAnexoA :: [PersonaRef]
personasAnexoA = fst (parsearPersonal personalAnexoA)

main :: IO ()
main = do
  putStrLn "=== PRUEBAS CAPACIDAD C1 (HASKELL) ==="
  let eventos = integrarAnexoA
      resultados =
        [ ("1. Epoch 2254786200 -> 2041-06-14T01:30:00Z",
           normalizarEpoch "2254786200" == Right "2041-06-14T01:30:00Z"),
          ("2. Hora 01.30 -> 2041-06-14T01:30:00Z",
           normalizarHoraPunto (2041, 6, 14) "01.30" == Right "2041-06-14T01:30:00Z"),
          ("3. Resolucion de alias Luka -> LP-04 y jefe -> JS-01",
           fmap fst (resolverPersona personasAnexoA "Luka") == Right "LP-04"
             && fmap fst (resolverPersona personasAnexoA "jefe") == Right "JS-01"),
          ("4. Normalizacion de modulo LAB_B -> LAB-B con rastro",
           resolverModulo "LAB_B" == Right (LAB_B, Just "Modulo normalizado: LAB_B -> LAB-B")),
          ("5. Registro corrupto tarjetas-00007 conservado con estado Corrupto",
           verificarEvento eventos "tarjetas-00007" (\e -> evEstado e == Corrupto && evTsUtc e == Nothing)),
          ("6. Registro duplicado tarjetas-00005 marcado como Duplicado",
           verificarEvento eventos "tarjetas-00005" (\e -> evEstado e == Duplicado)),
          ("7. Acceso DENEGADO de DV-02 en P4 (tarjetas-00012) marcado como Denegado",
           verificarEvento eventos "tarjetas-00012" (\e -> evEstado e == Denegado)),
          ("8. Contradiccion de tarjeta perdida LP-04 (tarjetas-00008 vs bitacora-00001)",
           verificarEvento eventos "tarjetas-00008" (\e -> evEstado e == Contradictorio)),
          ("9. Linea partida en bitacora-00003 ('Kimura con fiebre') reconstruida",
           verificarEvento eventos "bitacora-00003" (\e -> maybe False ("Kimura con fiebre" `isInfixOf`) (evMotivo e))),
          ("10. Total de eventos integrados del Anexo A = 75",
           length eventos == 75),
          ("11. Corte de energia por modulo: COM afectado y RAD no afectado",
           any (\e -> evTipo e == "energia_corte" && evModulo e == Just COM) eventos
             && not (any (\e -> evTipo e == "energia_corte" && evModulo e == Just RAD) eventos)),
          ("12. Restablecimiento global con modulo * y valor null",
           any (\e -> evTipo e == "energia_restablecido" && evModulo e == Just TODOS && evValor e == Nothing) eventos),
          ("13. radio-00007 no ubica a Marta en GEN por mencionar 'generadores'",
           verificarEvento eventos "radio-00007" (\e -> evModulo e == Nothing && maybe False ("generadores" `isInfixOf`) (evMotivo e))),
          ("14. bitacora-00004 no ubica al jefe en ALM por mencionar el almacen",
           verificarEvento eventos "bitacora-00004" (\e -> evModulo e == Nothing)),
          ("15. radio-00001 infiere RAD y deja rastro de la inferencia",
           verificarEvento eventos "radio-00001" (\e -> evModulo e == Just RAD && maybe False ("Modulo inferido" `isInfixOf`) (evMotivo e))),
          ("16. Fila invalida de personal.csv se conserva como diagnostico",
           let (_, diag) = parsearPersonal "tarjeta,nombre,cargo,accesos\nJS-01,Tomas,Jefe"
            in maybe False (\e -> evEstado e == Corrupto && evFuente e == FuentePersonal) (unicoEvento diag)),
          ("17. Timestamp invalido de energia genera evento Corrupto, no Valido",
           let evs = parsearEnergia "{\n\"ts\": \"malo\",\n\"tipo\": \"lectura\",\n\"consumo_kw\": {\n\"COM\": 2.1\n}\n}"
            in maybe False (\e -> evEstado e == Corrupto && evTsUtc e == Nothing) (unicoEvento evs)),
          ("18. Corte sin campo nota no desaparece",
           let evs = parsearEnergia "{\n\"ts\": \"2041-06-14T01:40:00\",\n\"tipo\": \"corte\",\n\"afecta\": [\n\"COM\"\n]\n}"
            in any (\e -> evTipo e == "energia_corte" && evModulo e == Just COM) evs),
          ("19. Consumo no numerico se conserva como evento Corrupto con ts",
           let evs = parsearEnergia "{\n\"ts\": \"2041-06-14T01:30:00\",\n\"tipo\": \"lectura\",\n\"consumo_kw\": {\n\"COM\": abc\n}\n}"
            in any (\e -> evEstado e == Corrupto && evTsUtc e == Just "2041-06-14T01:30:00Z") evs),
          ("20. Integracion determinista: dos ejecuciones producen la misma linea",
           integrarAnexoA == integrarAnexoA),
          ("21. DENEGADO con permiso vigente se marca contradictorio",
           let p = "tarjeta,nombre,cargo,accesos\nJS-01,Prueba,Jefe,P2 P3\n"
               e = "puerta,modulo_1,modulo_2,lector_tarjeta\nP2,DOR,LAB-A,si\n"
               t = "fecha_hora,tarjeta,puerta,desde,hacia,resultado\n2041-06-14T00:00:00,JS-01,P2,DOR,LAB-A,DENEGADO\n"
               evs = integrarEvidencia p e t "" "" "" "" ""
            in any (\ev -> evTipo ev == "tarjeta" && evEstado ev == Contradictorio) evs),
          ("22. Diagnostico de personal.csv llega a la linea de tiempo integrada",
           let p = "tarjeta,nombre,cargo,accesos\nJS-01,Prueba,Jefe,P2\nROTO\n"
               e = "puerta,modulo_1,modulo_2,lector_tarjeta\nP2,DOR,LAB-A,si\n"
               evs = integrarEvidencia p e "" "" "" "" "" ""
            in any (\ev -> evFuente ev == FuentePersonal && evEstado ev == Corrupto) evs)
        ]
  mapM_ mostrarResultado resultados
  let fallos = [nombre | (nombre, ok) <- resultados, not ok]
  if null fallos
    then putStrLn "\nTODAS LAS PRUEBAS PASARON EXITOSAMENTE."
    else putStrLn ("\nFALLARON " ++ show (length fallos) ++ " PRUEBAS.")

verificarEvento :: [Evento] -> String -> (Evento -> Bool) -> Bool
verificarEvento eventos idBuscado predicado =
  case [e | e <- eventos, evId e == idBuscado] of
    (ev : _) -> predicado ev
    []       -> False

unicoEvento :: [Evento] -> Maybe Evento
unicoEvento [e] = Just e
unicoEvento _   = Nothing

mostrarResultado :: (String, Bool) -> IO ()
mostrarResultado (nombre, True)  = putStrLn ("[OK]    " ++ nombre)
mostrarResultado (nombre, False) = putStrLn ("[FALLO] " ++ nombre)
