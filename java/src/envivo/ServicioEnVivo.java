package envivo;

import java.io.IOException;

// Programa principal de C3: une el receptor, la cola y el reenviador.
//   estación (simulador) -> Receptor -> ColaEnDisco -> Reenviador -> Scala
public class ServicioEnVivo {

    public static void main(String[] args) throws IOException {
        String carpeta = "datos-vivo";
        int puerto = 8090;
        String urlScala = System.getenv().getOrDefault("SCALA_URL", "http://localhost:8080/evidencia");

        ColaEnDisco cola = new ColaEnDisco(carpeta);

        Thread hiloReenviador = new Thread(new Reenviador(cola, new DestinoHttp(urlScala)));
        hiloReenviador.start();

        new Receptor(cola, carpeta, puerto).iniciar();
        System.out.println("Reenviando lecturas a " + urlScala);
        System.out.println("Pendientes por entregar al iniciar: " + cola.pendientes().size());
    }
}