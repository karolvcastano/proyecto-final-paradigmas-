package envivo;

// Programa corto para comprobar que Lectura produce el JSON del contrato.
public class PruebaLectura {

    public static void main(String[] args) {
        Lectura tarjeta = Lectura.tarjeta(1, "2041-07-05T10:00:00Z", "MR-03", "P5", "RAD", "GEN");
        Lectura presencia = Lectura.presencia(2, "2041-07-05T10:00:05Z", "GEN", 2);
        Lectura temperatura = Lectura.temperatura(3, "2041-07-05T10:00:10Z", "ALM", -6.3);

        System.out.println(tarjeta.aJson());
        System.out.println(presencia.aJson());
        System.out.println(temperatura.aJson());
    }
}