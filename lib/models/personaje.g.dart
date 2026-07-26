// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personaje.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersonajeAdapter extends TypeAdapter<Personaje> {
  @override
  final int typeId = 1;

  @override
  Personaje read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Personaje(
      id: fields[0] as String,
      nombre: fields[1] as String,
      fotoPath: fields[2] as String?,
      franquicia: fields[3] as String,
      tipo: fields[4] as TipoFranquicia,
      notas: fields[5] as String?,
      esFavorito: fields[6] as bool,
      fechaCreacion: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Personaje obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.fotoPath)
      ..writeByte(3)
      ..write(obj.franquicia)
      ..writeByte(4)
      ..write(obj.tipo)
      ..writeByte(5)
      ..write(obj.notas)
      ..writeByte(6)
      ..write(obj.esFavorito)
      ..writeByte(7)
      ..write(obj.fechaCreacion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonajeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TipoFranquiciaAdapter extends TypeAdapter<TipoFranquicia> {
  @override
  final int typeId = 0;

  @override
  TipoFranquicia read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TipoFranquicia.serie;
      case 1:
        return TipoFranquicia.pelicula;
      case 2:
        return TipoFranquicia.libro;
      default:
        return TipoFranquicia.serie;
    }
  }

  @override
  void write(BinaryWriter writer, TipoFranquicia obj) {
    switch (obj) {
      case TipoFranquicia.serie:
        writer.writeByte(0);
        break;
      case TipoFranquicia.pelicula:
        writer.writeByte(1);
        break;
      case TipoFranquicia.libro:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TipoFranquiciaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
