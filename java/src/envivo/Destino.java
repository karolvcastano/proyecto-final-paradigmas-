package envivo;

// A dónde se entregan las lecturas. Hoy es Scala por HTTP (DestinoHttp),
// pero en las pruebas usamos un destino falso que podemos "apagar".
public interface Destino {

    // Intenta entregar una lectura en formato JSON.
    // Devuelve true si quedó entregada y false si hay que reintentar más tarde.
    boolean enviar(String json);
}