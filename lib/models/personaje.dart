import 'package:hive/hive.dart';

part 'personaje.g.dart';

@HiveType(typeId: 0)
enum TipoFranquicia {
  @HiveField(0)
  serie,
  @HiveField(1)
  pelicula,
  @HiveField(2)
  libro,
}

@HiveType(typeId: 1)
class Personaje extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nombre;

  @HiveField(2)
  String? fotoPath;

  @HiveField(3)
  String franquicia;

  @HiveField(4)
  TipoFranquicia tipo;

  @HiveField(5)
  String? notas;

  @HiveField(6)
  bool esFavorito;

  @HiveField(7)
  DateTime fechaCreacion;

  Personaje({
    required this.id,
    required this.nombre,
    this.fotoPath,
    required this.franquicia,
    required this.tipo,
    this.notas,
    this.esFavorito = false,
    required this.fechaCreacion,
  });
}
