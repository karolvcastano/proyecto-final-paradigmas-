package envivo;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Set;

// Recibe las lecturas que transmite la estación (el simulador) con POST /lectura.
// Cada lectura llega como una línea de texto separada por comas:
//   temperatura,2026-11-17T22:30:00Z,ALM,-7.5
//   presencia,2026-11-17T22:30:00Z,GEN,2
//   tarjeta,2026-11-17T22:30:00Z,IV-07,P4,LAB-B,GEN
// Si la línea es válida, la guarda en la cola. Si no, la anota en rechazadas.txt con el motivo.
public class Receptor {

    private static final Set<String> MODULOS = Set.of("COM", "DOR", "LAB-A", "LAB-B", "GEN", "RAD", "ALM", "EXT");
    private static final Set<String> PUERTAS = Set.of("P1", "P2", "P3", "P4", "P5", "P6", "P7", "P8");
    private static final String FORMATO_HORA = "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z";

    private final ColaEnDisco cola;
    private final Path archivoRechazadas;
    private final int puerto;

    public Receptor(ColaEnDisco cola, String carpeta, int puerto) {
        this.cola = cola;
        this.archivoRechazadas = Path.of(carpeta).resolve("rechazadas.txt");
        this.puerto = puerto;
    }

    public void iniciar() throws IOException {
        HttpServer servidor = HttpServer.create(new InetSocketAddress(puerto), 0);
        servidor.createContext("/lectura", this::atender);
        servidor.start();
        System.out.println("Receptor escuchando en http://localhost:" + puerto + "/lectura");
    }

    private void atender(HttpExchange ex) throws IOException {
        if (!ex.getRequestMethod().equals("POST")) {
            responder(ex, 405, "solo se acepta POST");
            return;
        }
        String linea = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8).trim();
        try {
            Lectura lectura = recibir(linea);
            responder(ex, 201, lectura.getId());
        } catch (IllegalArgumentException e) {
            anotarRechazada(linea, e.getMessage());
            responder(ex, 400, e.getMessage());
        }
    }

    // Valida la línea y, si está bien, la guarda en la cola. synchronized: una lectura a la vez,
    // para que el número que se pide y el orden en cola.txt coincidan.
    public synchronized Lectura recibir(String linea) throws IOException {
        String[] partes = linea.split(",");
        String tipo = partes[0];

        if (tipo.equals("temperatura") || tipo.equals("presencia")) {
            exigir(partes.length == 4, "se esperaban 4 campos y llegaron " + partes.length);
            exigir(partes[1].matches(FORMATO_HORA), "hora no válida: " + partes[1]);
            exigir(MODULOS.contains(partes[2]), "módulo desconocido: " + partes[2]);
            double valor = numero(partes[3]);

            Lectura lectura;
            if (tipo.equals("temperatura")) {
                lectura = Lectura.temperatura(cola.siguienteNumero(), partes[1], partes[2], valor);
            } else {
                exigir(valor >= 0 && valor == Math.floor(valor), "número de personas no válido: " + partes[3]);
                lectura = Lectura.presencia(cola.siguienteNumero(), partes[1], partes[2], (int) valor);
            }
            cola.guardar(lectura);
            return lectura;
        }

        if (tipo.equals("tarjeta")) {
            exigir(partes.length == 6, "se esperaban 6 campos y llegaron " + partes.length);
            exigir(partes[1].matches(FORMATO_HORA), "hora no válida: " + partes[1]);
            exigir(PUERTAS.contains(partes[3]), "puerta desconocida: " + partes[3]);
            exigir(MODULOS.contains(partes[4]), "módulo desconocido: " + partes[4]);
            exigir(MODULOS.contains(partes[5]), "módulo desconocido: " + partes[5]);

            Lectura lectura = Lectura.tarjeta(cola.siguienteNumero(), partes[1], partes[2],
                    partes[3], partes[4], partes[5]);
            cola.guardar(lectura);
            return lectura;
        }

        throw new IllegalArgumentException("tipo desconocido: " + tipo);
    }

    // Si la condición no se cumple, rechaza la lectura con ese motivo.
    private static void exigir(boolean condicion, String motivo) {
        if (!condicion) {
            throw new IllegalArgumentException(motivo);
        }
    }

    private static double numero(String texto) {
        try {
            return Double.parseDouble(texto);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("valor no numérico: " + texto);
        }
    }

    // Ninguna lectura se descarta sin rastro: las inválidas quedan aquí con su motivo.
    private synchronized void anotarRechazada(String linea, String motivo) throws IOException {
        String registro = linea + " | motivo: " + motivo + System.lineSeparator();
        Files.writeString(archivoRechazadas, registro, StandardCharsets.UTF_8,
                StandardOpenOption.CREATE, StandardOpenOption.APPEND);
    }

    private static void responder(HttpExchange ex, int codigo, String texto) throws IOException {
        byte[] bytes = texto.getBytes(StandardCharsets.UTF_8);
        ex.sendResponseHeaders(codigo, bytes.length);
        ex.getResponseBody().write(bytes);
        ex.close();
    }
}