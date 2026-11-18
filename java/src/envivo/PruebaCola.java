package envivo;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

// Comprueba que la cola guarda, entrega y sobrevive a un reinicio.
public class PruebaCola {

    public static void main(String[] args) throws IOException {
        // Empezamos con una carpeta limpia para que la prueba siempre dé lo mismo.
        Path carpeta = Path.of("cola-prueba");
        Files.deleteIfExists(carpeta.resolve("cola.txt"));
        Files.deleteIfExists(carpeta.resolve("entregadas.txt"));

        ColaEnDisco cola = new ColaEnDisco("cola-prueba");
        cola.guardar(Lectura.temperatura(cola.siguienteNumero(), "2041-07-05T10:00:00Z", "ALM", -7.5));
        cola.guardar(Lectura.temperatura(cola.siguienteNumero(), "2041-07-05T10:00:05Z", "EXT", -39.4));
        cola.guardar(Lectura.presencia(cola.siguienteNumero(), "2041-07-05T10:00:10Z", "GEN", 1));
        System.out.println("Pendientes al inicio: " + cola.pendientes().size() + " (esperado 3)");

        cola.marcarEntregada();
        System.out.println("Pendientes tras entregar una: " + cola.pendientes().size() + " (esperado 2)");

        // Simulamos que el programa se cerró y volvió a abrir.
        ColaEnDisco colaReiniciada = new ColaEnDisco("cola-prueba");
        System.out.println("Pendientes tras reiniciar: " + colaReiniciada.pendientes().size() + " (esperado 2)");
        System.out.println("Siguiente número tras reiniciar: " + colaReiniciada.siguienteNumero() + " (esperado 4)");
    }
}