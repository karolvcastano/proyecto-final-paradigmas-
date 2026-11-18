package envivo;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;

// Guarda cada lectura en un archivo antes de enviarla, para que ninguna se pierda
// aunque Scala esté caído o el programa se cierre.
//
// Usa dos archivos:
//   cola.txt        una lectura por línea, en orden de llegada (nunca se borra nada)
//   entregadas.txt  cuántas lecturas de cola.txt ya recibió Scala
public class ColaEnDisco {

    private final Path archivoCola;
    private final Path archivoEntregadas;
    private int ultimoNumero;   // número de la última lectura guardada

    public ColaEnDisco(String carpeta) throws IOException {
        Path dir = Path.of(carpeta);
        Files.createDirectories(dir);
        archivoCola = dir.resolve("cola.txt");
        archivoEntregadas = dir.resolve("entregadas.txt");

        // Si el programa se reinicia, sigue contando donde iba: así no se repiten ids.
        ultimoNumero = leerLineas().size();
    }

    // Da el número para la próxima lectura (1, 2, 3...).
    public synchronized int siguienteNumero() {
        ultimoNumero = ultimoNumero + 1;
        return ultimoNumero;
    }

    // Escribe la lectura al final de cola.txt.
    public synchronized void guardar(Lectura lectura) throws IOException {
        String linea = lectura.aJson() + System.lineSeparator();
        Files.writeString(archivoCola, linea, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND, StandardOpenOption.SYNC);
    }

    // Devuelve las lecturas que todavía no ha recibido Scala, en orden.
    public synchronized List<String> pendientes() throws IOException {
        List<String> todas = leerLineas();
        int entregadas = leerEntregadas();
        return new ArrayList<>(todas.subList(entregadas, todas.size()));
    }

    // Anota que Scala ya recibió una lectura más.
    public synchronized void marcarEntregada() throws IOException {
        int entregadas = leerEntregadas() + 1;
        Files.writeString(archivoEntregadas, String.valueOf(entregadas), StandardCharsets.UTF_8);
    }

    private List<String> leerLineas() throws IOException {
        if (!Files.exists(archivoCola)) {
            return new ArrayList<>();
        }
        return Files.readAllLines(archivoCola, StandardCharsets.UTF_8);
    }

    private int leerEntregadas() throws IOException {
        if (!Files.exists(archivoEntregadas)) {
            return 0;
        }
        return Integer.parseInt(Files.readString(archivoEntregadas, StandardCharsets.UTF_8).trim());
    }
}