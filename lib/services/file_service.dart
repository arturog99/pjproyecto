import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

const int _dimensionMaxima = 1024;
const int _calidadJpg = 85;
// Evita intentar descomprimir fotografías que podrían agotar la memoria del
// dispositivo. Las fotos de móvil habituales quedan ampliamente cubiertas.
const int _tamanoMaximoArchivoOrigen = 12 * 1024 * 1024;

class FileService {
  static Future<String> copiarImagenALocal(String rutaOriginal) async {
    try {
      final archivoOriginal = File(rutaOriginal);
      final tamanoArchivo = await archivoOriginal.length();
      if (tamanoArchivo > _tamanoMaximoArchivoOrigen) {
        throw Exception('La imagen supera el tamaño máximo permitido de 12 MB.');
      }

      // Evita hacer una copia adicional de la foto al enviarla al isolate que
      // realiza la compresión.
      final bytesOriginales = await archivoOriginal.readAsBytes();
      final resultado = await compute(
        _redimensionarYComprimir,
        TransferableTypedData.fromList([bytesOriginales]),
      );
      final bytesComprimidos = resultado.materialize().asUint8List();

      final directorioApp = await getApplicationDocumentsDirectory();
      final directorioImagenes = Directory(path.join(directorioApp.path, 'imagenes'));

      if (!await directorioImagenes.exists()) {
        await directorioImagenes.create(recursive: true);
      }

      final nombreArchivo =
          '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.jpg';
      final rutaDestino = path.join(directorioImagenes.path, nombreArchivo);

      await File(rutaDestino).writeAsBytes(bytesComprimidos);

      return rutaDestino;
    } catch (e) {
      throw Exception('Error al procesar la imagen: $e');
    }
  }

  static Future<void> eliminarImagenLocal(String? rutaImagen) async {
    if (rutaImagen == null) return;

    try {
      final archivo = File(rutaImagen);
      if (await archivo.exists()) {
        await archivo.delete();
      }
    } catch (e) {
      print('Error al eliminar imagen: $e');
    }
  }

  static Future<void> limpiarImagenesHuerfanas(
    Iterable<String?> rutasEnUso,
  ) async {
    final rutasProtegidas = rutasEnUso.whereType<String>().toSet();
    final directorioApp = await getApplicationDocumentsDirectory();
    final directorioImagenes = Directory(path.join(directorioApp.path, 'imagenes'));

    if (!await directorioImagenes.exists()) return;

    await for (final entidad in directorioImagenes.list(followLinks: false)) {
      if (entidad is File && !rutasProtegidas.contains(entidad.path)) {
        await entidad.delete();
      }
    }
  }
}

TransferableTypedData _redimensionarYComprimir(
  TransferableTypedData datosTransferibles,
) {
  final bytesOriginales = datosTransferibles.materialize().asUint8List();
  final imagenDecodificada = img.decodeImage(bytesOriginales);

  if (imagenDecodificada == null) {
    throw Exception('Formato de imagen no soportado');
  }

  img.Image imagenFinal = imagenDecodificada;

  if (imagenDecodificada.width > _dimensionMaxima || imagenDecodificada.height > _dimensionMaxima) {
    final esMasAnchaQueAlta = imagenDecodificada.width >= imagenDecodificada.height;
    imagenFinal = img.copyResize(
      imagenDecodificada,
      width: esMasAnchaQueAlta ? _dimensionMaxima : null,
      height: esMasAnchaQueAlta ? null : _dimensionMaxima,
    );
  }

  return TransferableTypedData.fromList([
    Uint8List.fromList(img.encodeJpg(imagenFinal, quality: _calidadJpg)),
  ]);
}
