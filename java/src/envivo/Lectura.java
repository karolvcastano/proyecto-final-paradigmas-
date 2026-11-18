package envivo;

// Una lectura en vivo de la estación, con los 14 campos del contrato del equipo
// (haskell/evento.schema.json).
public class Lectura {

    private final String id;          // por ejemplo "vivo-00001"
    private final int numero;         // posición de la lectura en la llegada (1, 2, 3...)
    private final String tipo;        // "tarjeta", "presencia" o "temperatura"
    private final String tsUtc;       // hora en UTC, por ejemplo "2041-07-05T10:00:00Z"
    private final String persona;     // código de la tarjeta (solo en tipo tarjeta)
    private final String modulo;      // módulo medido (solo en presencia y temperatura)
    private final String puerta;      // solo en tipo tarjeta
    private final String desde;       // solo en tipo tarjeta
    private final String hacia;       // solo en tipo tarjeta
    private final Double valor;       // personas o grados (solo en sensores)

    private Lectura(int numero, String tipo, String tsUtc, String persona, String modulo,
                    String puerta, String desde, String hacia, Double valor) {
        this.id = String.format("vivo-%05d", numero);
        this.numero = numero;
        this.tipo = tipo;
        this.tsUtc = tsUtc;
        this.persona = persona;
        this.modulo = modulo;
        this.puerta = puerta;
        this.desde = desde;
        this.hacia = hacia;
        this.valor = valor;
    }

    // Alguien pasó una tarjeta por una puerta.
    public static Lectura tarjeta(int numero, String tsUtc, String tarjeta,
                                  String puerta, String desde, String hacia) {
        return new Lectura(numero, "tarjeta", tsUtc, tarjeta, null, puerta, desde, hacia, null);
    }

    // Un sensor contó cuántas personas hay en un módulo.
    public static Lectura presencia(int numero, String tsUtc, String modulo, int personas) {
        return new Lectura(numero, "presencia", tsUtc, null, modulo, null, null, null, (double) personas);
    }

    // Un sensor midió la temperatura de un módulo.
    public static Lectura temperatura(int numero, String tsUtc, String modulo, double grados) {
        return new Lectura(numero, "temperatura", tsUtc, null, modulo, null, null, null, grados);
    }

    public String getId() {
        return id;
    }

    // Convierte la lectura en una línea de texto JSON con los 14 campos del contrato.
    public String aJson() {
        return "{"
                + "\"id\": " + texto(id) + ", "
                + "\"fuente\": \"simulador\", "
                + "\"linea_original\": " + numero + ", "
                + "\"tipo\": " + texto(tipo) + ", "
                + "\"ts_original\": " + texto(tsUtc) + ", "
                + "\"ts_utc\": " + texto(tsUtc) + ", "
                + "\"persona\": " + texto(persona) + ", "
                + "\"modulo\": " + texto(modulo) + ", "
                + "\"puerta\": " + texto(puerta) + ", "
                + "\"desde\": " + texto(desde) + ", "
                + "\"hacia\": " + texto(hacia) + ", "
                + "\"valor\": " + valorJson() + ", "
                + "\"estado\": \"valido\", "
                + "\"motivo\": null"
                + "}";
    }

    // Pone comillas a un texto, o escribe null si no hay dato.
    private static String texto(String dato) {
        if (dato == null) {
            return "null";
        }
        return "\"" + dato.replace("\"", "\\\"") + "\"";
    }

    // Escribe el valor, o null si no hay. Los enteros salen sin decimales (2 en vez de 2.0).
    private String valorJson() {
        if (valor == null) {
            return "null";
        }
        if (valor == Math.floor(valor)) {
            return String.valueOf(valor.intValue());
        }
        return String.valueOf(valor);
    }
}