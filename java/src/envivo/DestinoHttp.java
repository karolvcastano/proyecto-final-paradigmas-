package envivo;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

// Entrega las lecturas a Scala con POST /evidencia.
public class DestinoHttp implements Destino {

    private final String url;
    private final HttpClient cliente;

    public DestinoHttp(String url) {
        this.url = url;
        // Si Scala no contesta en 2 segundos, se considera caído (así nunca nos quedamos colgados).
        this.cliente = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(2))
                .build();
    }

    @Override
    public boolean enviar(String json) {
        try {
            HttpRequest peticion = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(5))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();
            HttpResponse<String> respuesta = cliente.send(peticion, HttpResponse.BodyHandlers.ofString());
            int codigo = respuesta.statusCode();

            if (codigo == 201) {
                return true;   // Scala la guardó
            }
            if (codigo == 400) {
                // Scala la revisó y no la aceptó (por ejemplo, el id ya existía).
                // Reintentar daría el mismo resultado; la lectura sigue en cola.txt como rastro.
                System.out.println("Scala rechazó la lectura: " + respuesta.body());
                return true;
            }
            return false;      // otro error de Scala: reintentar
        } catch (Exception e) {
            return false;      // Scala apagado o sin respuesta: reintentar
        }
    }
}