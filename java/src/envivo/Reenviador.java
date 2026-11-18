package envivo;

import java.io.IOException;
import java.util.List;

// Corre en su propio hilo. Cada segundo revisa la cola y envía las lecturas pendientes,
// en orden. Si el destino falla, se detiene y lo vuelve a intentar en la siguiente vuelta.
public class Reenviador implements Runnable {

    private final ColaEnDisco cola;
    private final Destino destino;

    public Reenviador(ColaEnDisco cola, Destino destino) {
        this.cola = cola;
        this.destino = destino;
    }

    @Override
    public void run() {
        while (true) {
            try {
                enviarPendientes();
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                return;   // alguien pidió detener el hilo
            } catch (IOException e) {
                System.out.println("Error leyendo la cola: " + e.getMessage());
            }
        }
    }

    private void enviarPendientes() throws IOException {
        List<String> pendientes = cola.pendientes();
        for (String json : pendientes) {
            if (destino.enviar(json)) {
                cola.marcarEntregada();
            } else {
                // Si esta falla, no enviamos las siguientes: así se conserva el orden.
                return;
            }
        }
    }
}