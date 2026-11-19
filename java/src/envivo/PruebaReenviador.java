package envivo;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

// Comprueba que ninguna lectura se pierde cuando el destino está caído.
public class PruebaReenviador {

    // Un destino de mentira que podemos apagar y encender.
    static class DestinoFalso implements Destino {
        boolean encendido = false;
        List<String> recibidas = new ArrayList<>();

        @Override
        public synchronized boolean enviar(String json) {
            if (!encendido) {
                return false;
            }
            recibidas.add(json);
            return true;
        }
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        Path carpeta = Path.of("cola-prueba");
        Files.deleteIfExists(carpeta.resolve("cola.txt"));
        Files.deleteIfExists(carpeta.resolve("entregadas.txt"));

        ColaEnDisco cola = new ColaEnDisco("cola-prueba");
        DestinoFalso destino = new DestinoFalso();

        Thread hilo = new Thread(new Reenviador(cola, destino));
        hilo.start();

        // Llegan tres lecturas mientras el destino está apagado.
        cola.guardar(Lectura.temperatura(cola.siguienteNumero(), "2041-07-05T10:00:00Z", "ALM", -7.5));
        cola.guardar(Lectura.temperatura(cola.siguienteNumero(), "2041-07-05T10:00:05Z", "EXT", -39.4));
        cola.guardar(Lectura.presencia(cola.siguienteNumero(), "2041-07-05T10:00:10Z", "GEN", 1));

        Thread.sleep(2500);
        System.out.println("Destino apagado -> recibidas: " + destino.recibidas.size()
                + ", pendientes: " + cola.pendientes().size() + " (esperado 0 y 3)");

        destino.encendido = true;
        Thread.sleep(2500);
        System.out.println("Destino encendido -> recibidas: " + destino.recibidas.size()
                + ", pendientes: " + cola.pendientes().size() + " (esperado 3 y 0)");
        System.out.println("Primera recibida: " + destino.recibidas.get(0).substring(0, 20) + "... (esperado vivo-00001)");

        hilo.interrupt();
    }
}