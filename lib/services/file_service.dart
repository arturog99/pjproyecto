import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

const int _dimensionMaxima = 1024;
const int _calidadJpg = 85;

class FileService {
  static Future<String> copiarImagenALocal(String rutaOriginal) async {
    try {
      final bytesOriginales = await File(rutaOriginal).readAsBytes();

      final bytesComprimidos = await compute(_redimensionarYComprimir, bytesOriginales);

      final directorioApp = await getApplicationDocumentsDirectory();
      final directorioImagenes = Directory(path.join(directorioApp.path, 'imagenes'));

      if (!await directorioImagenes.exists()) {
        await directorioImagenes.create(recursive: true);
      }

      final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
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
}

Uint8List _redimensionarYComprimir(Uint8List bytesOriginales) {
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

  return Uint8List.fromList(img.encodeJpg(imagenFinal, quality: _calidadJpg));
}
