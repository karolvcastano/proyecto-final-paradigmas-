package custodia

import java.sql.{Connection, DriverManager, ResultSet, Types}

// Repositorio en MySQL 8.4 (Docker). Misma interfaz que RepoEnMemoria.
// Los métodos están sincronizados para que la cadena de hashes no se bifurque con peticiones simultáneas.
final class RepoMySQL(url: String, usuario: String, clave: String) extends EvidenciaRepo:
  private val conexion: Connection = DriverManager.getConnection(url, usuario, clave)
  crearTabla()

  def ultimoHash: String = synchronized {
    val ps = conexion.prepareStatement("SELECT hash FROM registros ORDER BY seq DESC LIMIT 1")
    try
      val rs = ps.executeQuery()
      if rs.next() then rs.getString("hash") else "GENESIS"
    finally ps.close()
  }

  def agregar(registro: Registro): Unit = synchronized {
    val e = registro.evento
    val sql =
      """INSERT INTO registros
        |(id, fuente, linea_original, tipo, ts_original, ts_utc, persona, modulo,
        | puerta, desde, hacia, valor, estado, motivo, hash)
        |VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""".stripMargin
    val ps = conexion.prepareStatement(sql)
    try
      ps.setString(1, e.id)
      ps.setString(2, e.fuente)
      ps.setInt(3, e.lineaOriginal)
      ps.setString(4, e.tipo)
      ps.setString(5, e.tsOriginal.orNull)
      ps.setString(6, e.tsUtc.orNull)
      ps.setString(7, e.persona.orNull)
      ps.setString(8, e.modulo.orNull)
      ps.setString(9, e.puerta.orNull)
      ps.setString(10, e.desde.orNull)
      ps.setString(11, e.hacia.orNull)
      e.valor match
        case Some(v) => ps.setDouble(12, v)
        case None    => ps.setNull(12, Types.DOUBLE)
      ps.setString(13, e.estado)
      ps.setString(14, e.motivo.orNull)
      ps.setString(15, registro.hash)
      ps.executeUpdate()
    finally ps.close()
  }

  def todos: List[Registro] = synchronized {
    val ps = conexion.prepareStatement("SELECT * FROM registros ORDER BY seq")
    try
      val rs = ps.executeQuery()
      val lista = scala.collection.mutable.ListBuffer.empty[Registro]
      while rs.next() do lista += leer(rs)
      lista.toList
    finally ps.close()
  }

  private def crearTabla(): Unit =
    val st = conexion.createStatement()
    try
      st.executeUpdate(
        """CREATE TABLE IF NOT EXISTS registros (
          |  seq BIGINT AUTO_INCREMENT PRIMARY KEY,
          |  id VARCHAR(64) NOT NULL,
          |  fuente VARCHAR(64) NOT NULL,
          |  linea_original INT NOT NULL,
          |  tipo VARCHAR(64) NOT NULL,
          |  ts_original VARCHAR(64),
          |  ts_utc VARCHAR(64),
          |  persona VARCHAR(64),
          |  modulo VARCHAR(64),
          |  puerta VARCHAR(64),
          |  desde VARCHAR(64),
          |  hacia VARCHAR(64),
          |  valor DOUBLE,
          |  estado VARCHAR(32) NOT NULL,
          |  motivo TEXT,
          |  hash CHAR(64) NOT NULL,
          |  INDEX idx_id (id)
          |)""".stripMargin
      )
    finally st.close()

  private def opcional(rs: ResultSet, columna: String): Option[String] =
    Option(rs.getString(columna))

  private def leer(rs: ResultSet): Registro =
    // El valor se lee antes que las demás columnas, porque wasNull solo sirve para la última lectura.
    val valorLeido = rs.getDouble("valor")
    val valor = if rs.wasNull then None else Some(valorLeido)
    val evento = Evento(
      id = rs.getString("id"),
      fuente = rs.getString("fuente"),
      lineaOriginal = rs.getInt("linea_original"),
      tipo = rs.getString("tipo"),
      tsOriginal = opcional(rs, "ts_original"),
      tsUtc = opcional(rs, "ts_utc"),
      persona = opcional(rs, "persona"),
      modulo = opcional(rs, "modulo"),
      puerta = opcional(rs, "puerta"),
      desde = opcional(rs, "desde"),
      hacia = opcional(rs, "hacia"),
      valor = valor,
      estado = rs.getString("estado"),
      motivo = opcional(rs, "motivo")
    )
    Registro(evento, rs.getString("hash"))
