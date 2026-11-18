package envivo;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Random;

// Imita a la estación Halley-7, que sigue transmitiendo lecturas.
// Uso: java -cp out envivo.Simulador [milisegundos entre lecturas] [cantidad, 0 = sin fin]
public class Simulador {

    private static final String URL_RECEPTOR = "http://localhost:8090/lectura";
    private static final String[] MODULOS = {"COM", "DOR", "LAB-A", "LAB-B", "GEN", "RAD", "ALM"};

    // Pasos que el personal sí puede dar con su tarjeta (según personal.csv y estacion.csv).
    private static final String[][] PASOS_TARJETA = {
            {"JS-01", "P8", "ALM", "EXT"},
            {"MR-03", "P5", "RAD", "GEN"},
            {"MR-03", "P7", "GEN", "ALM"},
            {"DV-02", "P2", "DOR", "LAB-A"},
            {"AK-05", "P3", "LAB-A", "LAB-B"},
            {"LP-04", "P5", "GEN", "RAD"},
    };

    private static final Random azar = new Random();
    private static final HttpClient cliente = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    public static void main(String[] args) throws InterruptedException {
        int intervalo = args.length > 0 ? Integer.parseInt(args[0]) : 2000;
        int cantidad = args.length > 1 ? Integer.parseInt(args[1]) : 0;

        System.out.println("Simulador: una lectura cada " + intervalo + " ms");
        int enviadas = 0;
        while (cantidad == 0 || enviadas < cantidad) {
            String linea = nuevaLectura();
            enviarHastaQueLlegue(linea);
            enviadas++;
            Thread.sleep(intervalo);
        }
    }

    // Arma una lectura al azar: 40 % temperatura, 40 % presencia, 20 % tarjeta.
    static String nuevaLectura() {
        String hora = Instant.now().truncatedTo(ChronoUnit.SECONDS).toString();
        int dado = azar.nextInt(10);

        if (dado < 4) {
            boolean exterior = azar.nextBoolean();
            double base = exterior ? -39.0 : -7.0;
            double grados = Math.round((base + azar.nextDouble() * 2 - 1) * 10) / 10.0;
            return "temperatura," + hora + "," + (exterior ? "EXT" : "ALM") + "," + grados;
        }
        if (dado < 8) {
            String modulo = MODULOS[azar.nextInt(MODULOS.length)];
            return "presencia," + hora + "," + modulo + "," + azar.nextInt(3);
        }
        String[] paso = PASOS_TARJETA[azar.nextInt(PASOS_TARJETA.length)];
        return "tarjeta," + hora + "," + String.join(",", paso);
    }

    // Si el receptor no contesta, la estación vuelve a intentar la misma lectura: no se pierde.
    static void enviarHastaQueLlegue(String linea) throws InterruptedException {
        while (true) {
            try {
                HttpRequest peticion = HttpRequest.newBuilder(URI.create(URL_RECEPTOR))
                        .timeout(Duration.ofSeconds(5))
                        .POST(HttpRequest.BodyPublishers.ofString(linea))
                        .build();
                HttpResponse<String> respuesta = cliente.send(peticion, HttpResponse.BodyHandlers.ofString());
                System.out.println(linea + "  ->  " + respuesta.statusCode() + " " + respuesta.body());
                return;
            } catch (java.io.IOException e) {
                System.out.println("Receptor no responde, reintento en 1 s: " + linea);
                Thread.sleep(1000);
            }
        }
    }
}