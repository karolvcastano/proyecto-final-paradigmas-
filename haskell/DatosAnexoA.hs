-- DatosAnexoA.hs
-- Contiene el texto integro de los 8 archivos del Anexo A del enunciado
-- para poder ejecutar y probar la Capacidad C1 sin depender de carpetas externas.

module DatosAnexoA where

personalAnexoA :: String
personalAnexoA =
  unlines
    [ "tarjeta,nombre,cargo,accesos",
      "JS-01,Tomás Okafor,Jefe de estación,P2 P3 P4 P5 P7 P8",
      "DV-02,Daniel Vidal,Médico,P2 P3",
      "MR-03,Marta Ruiz,Ingeniera eléctrica,P2 P4 P5 P7",
      "LP-04,Lucas Petrov,Radiooperador,P2 P5 P7",
      "AK-05,Aiko Kimura,Bióloga,P2 P3",
      "IV-07,Irene Valcárcel,Glacióloga,P2 P3 P4"
    ]

estacionAnexoA :: String
estacionAnexoA =
  unlines
    [ "puerta,modulo_1,modulo_2,lector_tarjeta",
      "P1,COM,DOR,no",
      "P2,DOR,LAB-A,si",
      "P3,LAB-A,LAB-B,si",
      "P4,LAB-B,GEN,si",
      "P5,GEN,RAD,si",
      "P6,RAD,COM,no",
      "P7,GEN,ALM,si",
      "P8,ALM,EXT,si"
    ]

tarjetasAnexoA :: String
tarjetasAnexoA =
  unlines
    [ "fecha_hora,tarjeta,puerta,desde,hacia,resultado",
      "2041-06-14T00:12:04,IV-07,P2,DOR,LAB-A,OK",
      "2041-06-14T00:30:41,IV-07,P3,LAB-A,LAB-B,OK",
      "2041-06-14T01:08:15,MR-03,P5,RAD,GEN,OK",
      "2041-06-14T01:20:33,IV-07,P4,LAB-B,GEN,OK",
      "2041-06-14T01:20:33,IV-07,P4,LAB-B,GEN,OK",
      "2041-06-14T01:35:02,MR-03,P5,GEN,RAD,OK",
      "2041-06-14T0#:4?:1?,AK-0?,P2,DO",
      "2041-06-14T01:39:47,LP-04,P7,GEN,ALM,OK",
      "2041-06-14T02:18:10,DV-02,P2,DOR,LAB-A,OK",
      "2041-06-14T02:22:36,DV-02,P3,LAB-A,LAB-B,OK",
      "2041-06-14T02:30:12,AK-05,P2,DOR,LAB-A,OK",
      "2041-06-14T02:40:05,DV-02,P4,LAB-B,GEN,DENEGADO",
      "2041-06-14T02:41:20,DV-02,P3,LAB-B,LAB-A,OK"
    ]

radioAnexoA :: String
radioAnexoA =
  unlines
    [ "TRANSCRIPCIÓN AUTOMÁTICA - CONSOLA DE RADIO HALLEY-7 - 14/06/2041",
      "[00:52] Petrov: Okafor, aquí radio. La doctora sigue en el B, dice que no la esperen para la",
      "cena.",
      "[01:27] Okafor: Doc, ¿puedes revisar a Kimura? Tiene fiebre.",
      "[01:28] Vidal: Voy para dormitorios.",
      "[01:47] Petrov: Se fue la luz. Otra vez.",
      "[02:00] Petrov: Okafor, ¿me copias? Sigo sin luz aquí en radio.",
      "[02:23] jefe: Volvió la energía. ¿Alguien ha visto a Irene?",
      "[02:24] Marta Ruiz: La dejé en generadores a la una y media. Estaba bien.",
      "[02:31] Luka: Durante el corte escuché la puerta exterior. Pensé que era el viento."
    ]

presenciaAnexoA :: String
presenciaAnexoA =
  unlines
    [ "hora;modulo;personas",
      "01.30;COM;1",
      "01.30;DOR;2",
      "01.30;LAB-A;0",
      "01.30;LAB_B;0",
      "01.30;GEN;2",
      "01.30;RAD;1",
      "01.30;ALM;0",
      "01.40;*;SIN_ENERGIA",
      "02.20;COM;1",
      "02.20;DOR;1",
      "02.20;LAB-A;1",
      "02.20;LAB-B;0",
      "02.20;GEN;0",
      "02.20;RAD;2",
      "02.20;ALM;0"
    ]

temperaturaAnexoA :: String
temperaturaAnexoA =
  unlines
    [ "epoch,sensor,celsius",
      "2254786200,T-ALM,12.0",
      "2254786200,T-EXT,-38.2",
      "2254786800,T-ALM,12.1",
      "2254786800,T-EXT,-38.4",
      "2254787400,T-ALM,11.8",
      "2254787400,T-EXT,-38.9",
      "2254787700,T-ALM,2.9",
      "2254787700,T-EXT,-39.0",
      "2254788000,T-ALM,-6.3",
      "2254788000,T-EXT,-39.1",
      "2254788600,T-ALM,-7.1",
      "2254788600,T-EXT,-39.3",
      "2254789200,T-ALM,-7.4",
      "2254789200,T-EXT,-39.2"
    ]

energiaAnexoA :: String
energiaAnexoA =
  unlines
    [ "{",
      "\"estacion\": \"Halley-7\",",
      "\"registros\": [",
      "{",
      "\"ts\": \"2041-06-14T01:30:00\",",
      "\"tipo\": \"lectura\",",
      "\"consumo_kw\": {",
      "\"COM\": 2.1,",
      "\"DOR\": 1.4,",
      "\"LAB-A\": 0.3,",
      "\"LAB-B\": 0.9,",
      "\"GEN\": 5.2,",
      "\"RAD\": 1.1,",
      "\"ALM\": 0.2",
      "}",
      "},",
      "{",
      "\"ts\": \"2041-06-14T01:40:00\",",
      "\"tipo\": \"corte\",",
      "\"afecta\": [",
      "\"COM\",",
      "\"DOR\",",
      "\"LAB-A\",",
      "\"LAB-B\",",
      "\"GEN\",",
      "\"ALM\"",
      "],",
      "\"nota\": \"RAD continua con baterias\"",
      "},",
      "{",
      "\"ts\": \"2041-06-14T02:15:00\",",
      "\"tipo\": \"restablecido\"",
      "},",
      "{",
      "\"ts\": \"2041-06-14T02:20:00\",",
      "\"tipo\": \"lectura\",",
      "\"consumo_kw\": {",
      "\"COM\": 2.3,",
      "\"DOR\": 1.2,",
      "\"LAB-A\": 0.6,",
      "\"LAB-B\": 0.9,",
      "\"GEN\": 4.8,",
      "\"RAD\": 1.3,",
      "\"ALM\": 0.4",
      "}",
      "}",
      "]",
      "}"
    ]

bitacoraAnexoA :: String
bitacoraAnexoA =
  unlines
    [ "BITÁCORA DEL JEFE DE ESTACIÓN (manuscrita, digitalizada)",
      "",
      "12/06 - Día 4. Petrov dice que perdió su tarjeta de acceso. Le haré una nueva cuando pase la tormenta.",
      "",
      "13/06 - Día 5. La doctora Valcárcel insiste otra vez en salir a revisar la antena del sur. Le dije que no hasta que pase la tormenta.",
      "",
      "14/06 - Día 6, 01:50 aprox. Sin luz otra vez. Escribo con linterna en el comedor. Kimura con",
      "",
      "fiebre, el doc está con ella.",
      "",
      "14/06 - Día 6, 03:00. Irene no aparece. Revisamos todos los módulos. La puerta exterior estaba cerrada, pero el almacén estaba helado."
    ]
