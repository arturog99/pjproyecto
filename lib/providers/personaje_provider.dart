import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import '../models/personaje.dart';
import '../services/file_service.dart';

const int _tamanoMaximoBackup = 100 * 1024 * 1024;
const int _maximoPersonajesImportados = 10000;

enum CriterioOrden { ninguno, nombre, fecha }

class ResultadoImportacion {
  final int nuevos;
  final int duplicados;
  final List<Map<String, dynamic>> datosCrudos;
  final Directory directorioExtraido;

  ResultadoImportacion({
    required this.nuevos,
    required this.duplicados,
    required this.datosCrudos,
    required this.directorioExtraido,
  });
}

class PersonajeProvider with ChangeNotifier {
  late Box<Personaje> _personajesBox;
  List<Personaje> _personajes = [];
  List<Personaje> _personajesFiltrados = [];
  String _busqueda = '';
  TipoFranquicia? _filtroTipo;
  bool _soloFavoritos = false;
  CriterioOrden _criterioOrden = CriterioOrden.ninguno;
  bool _estaCargando = true;
  String? _errorCarga;

  List<Personaje> get personajes => _personajesFiltrados;
  List<Personaje> get todosPersonajes => _personajes;
  String get busqueda => _busqueda;
  TipoFranquicia? get filtroTipo => _filtroTipo;
  bool get soloFavoritos => _soloFavoritos;
  CriterioOrden get criterioOrden => _criterioOrden;
  bool get estaCargando => _estaCargando;
  String? get errorCarga => _errorCarga;

  PersonajeProvider() {
    _inicializarProvider();
  }

  Future<void> _inicializarProvider() async {
    try {
      _personajesBox = await Hive.openBox<Personaje>('personajes');
      _cargarPersonajes(notificar: false);
      await FileService.limpiarImagenesHuerfanas(
        _personajes.map((personaje) => personaje.fotoPath),
      );
    } catch (e) {
      _errorCarga = 'No se pudieron cargar los personajes: $e';
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  void _cargarPersonajes({bool notificar = true}) {
    _personajes = _personajesBox.values.toList();
    _aplicarOrden();
    _aplicarFiltros(notificar: notificar);
  }

  void _aplicarOrden() {
    switch (_criterioOrden) {
      case CriterioOrden.nombre:
        _personajes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        break;
      case CriterioOrden.fecha:
        _personajes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
        break;
      case CriterioOrden.ninguno:
        break;
    }
  }

  void _aplicarFiltros({bool notificar = true}) {
    _personajesFiltrados = _personajes.where((personaje) {
      bool coincideBusqueda = personaje.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          personaje.franquicia.toLowerCase().contains(_busqueda.toLowerCase());
      bool coincideTipo = _filtroTipo == null || personaje.tipo == _filtroTipo;
      bool coincideFavorito = !_soloFavoritos || personaje.esFavorito;
      return coincideBusqueda && coincideTipo && coincideFavorito;
    }).toList();

    if (notificar) notifyListeners();
  }

  void setBusqueda(String valor) {
    _busqueda = valor;
    _aplicarFiltros();
  }

  void setFiltroTipo(TipoFranquicia? tipo) {
    _filtroTipo = tipo;
    _aplicarFiltros();
  }

  void setSoloFavoritos(bool valor) {
    _soloFavoritos = valor;
    _aplicarFiltros();
  }

  Future<void> agregarPersonaje(Personaje personaje) async {
    await _personajesBox.put(personaje.id, personaje);
    _cargarPersonajes();
  }

  Future<void> actualizarPersonaje(Personaje personaje) async {
    await _personajesBox.put(personaje.id, personaje);
    _cargarPersonajes();
  }

  Future<void> eliminarPersonaje(Personaje personaje) async {
    await FileService.eliminarImagenLocal(personaje.fotoPath);
    await _personajesBox.delete(personaje.id);
    _cargarPersonajes();
  }

  Future<void> toggleFavorito(Personaje personaje) async {
    personaje.esFavorito = !personaje.esFavorito;
    await _personajesBox.put(personaje.id, personaje);
    _cargarPersonajes();
  }

  void ordenarPorNombre() {
    _criterioOrden = CriterioOrden.nombre;
    _aplicarOrden();
    _aplicarFiltros();
  }

  void ordenarPorFecha() {
    _criterioOrden = CriterioOrden.fecha;
    _aplicarOrden();
    _aplicarFiltros();
  }

  // ---------- EXPORTAR: .zip escrito directo a disco ----------

  Future<void> exportarDatos(String rutaDestino) async {
    final directorioTemp = await getTemporaryDirectory();

    final datos = _personajes.map((p) {
      String? fotoRelativa;
      if (p.fotoPath != null && File(p.fotoPath!).existsSync()) {
        fotoRelativa = 'images/${path.basename(p.fotoPath!)}';
      }
      return {
        'id': p.id,
        'nombre': p.nombre,
        'fotoRelativa': fotoRelativa,
        'franquicia': p.franquicia,
        'tipo': p.tipo.index,
        'notas': p.notas,
        'esFavorito': p.esFavorito,
        'fechaCreacion': p.fechaCreacion.toIso8601String(),
      };
    }).toList();

    final jsonFile = File(path.join(directorioTemp.path, 'data.json'));
    await jsonFile.writeAsString(jsonEncode(datos));

    final encoder = ZipFileEncoder();
    encoder.create(rutaDestino);
    encoder.addFile(jsonFile, 'data.json');

    for (final p in _personajes) {
      if (p.fotoPath != null) {
        final fotoFile = File(p.fotoPath!);
        if (await fotoFile.exists()) {
          encoder.addFile(fotoFile, 'images/${path.basename(p.fotoPath!)}');
        }
      }
    }

    encoder.close();
    await jsonFile.delete();
  }

  // ---------- IMPORTAR: fase 1, solo analizar (sin escribir nada) ----------

  Future<ResultadoImportacion> analizarImportacion(String rutaZip) async {
    final archivoZip = File(rutaZip);
    if (!await archivoZip.exists()) {
      throw Exception('No se encontró el archivo seleccionado.');
    }
    if (await archivoZip.length() > _tamanoMaximoBackup) {
      throw Exception('El backup supera el tamaño máximo permitido de 100 MB.');
    }

    final directorioTemp = await getTemporaryDirectory();
    final directorioExtraido = Directory(
      path.join(directorioTemp.path, 'import_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await directorioExtraido.create(recursive: true);

    try {
      await extractFileToDisk(rutaZip, directorioExtraido.path);

      final jsonFile = File(path.join(directorioExtraido.path, 'data.json'));
      if (!await jsonFile.exists()) {
        throw Exception('El archivo no tiene el formato esperado (falta data.json).');
      }

      final contenido = jsonDecode(await jsonFile.readAsString());
      if (contenido is! List || contenido.length > _maximoPersonajesImportados) {
        throw Exception('El backup contiene datos no válidos o demasiados personajes.');
      }

      final lista = contenido.map<Map<String, dynamic>>((item) {
        if (item is! Map) {
          throw Exception('El backup contiene una ficha con formato inválido.');
        }
        return Map<String, dynamic>.from(item);
      }).toList();

      for (final item in lista) {
        _validarDatosImportados(item);
      }

      final duplicados = lista.where((item) => _personajesBox.containsKey(item['id'])).length;

      return ResultadoImportacion(
        nuevos: lista.length - duplicados,
        duplicados: duplicados,
        datosCrudos: lista,
        directorioExtraido: directorioExtraido,
      );
    } catch (_) {
      if (await directorioExtraido.exists()) {
        await directorioExtraido.delete(recursive: true);
      }
      rethrow;
    }
  }

  // ---------- IMPORTAR: fase 2, confirmar y escribir ----------

  Future<void> confirmarImportacion(
    ResultadoImportacion resultado, {
    required bool sobrescribirDuplicados,
  }) async {
    final Map<String, Personaje> paraGuardar = {};
    final imagenesAnteriores = <String?>[];

    for (final item in resultado.datosCrudos) {
      final id = item['id'] as String;
      final yaExiste = _personajesBox.containsKey(id);
      if (yaExiste && !sobrescribirDuplicados) continue;
      if (yaExiste) {
        imagenesAnteriores.add(_personajesBox.get(id)?.fotoPath);
      }

      String? fotoPath;
      final fotoRelativa = item['fotoRelativa'] as String?;
      if (fotoRelativa != null) {
        final origen = File(
          path.join(
            resultado.directorioExtraido.path,
            'images',
            path.basename(fotoRelativa),
          ),
        );
        if (await origen.exists()) {
          try {
            fotoPath = await FileService.copiarImagenALocal(origen.path);
          } catch (e) {
            debugPrint('Error al restaurar imagen de ${item['nombre']}: $e');
          }
        }
      }

      paraGuardar[id] = Personaje(
        id: id,
        nombre: item['nombre'],
        fotoPath: fotoPath,
        franquicia: item['franquicia'],
        tipo: TipoFranquicia.values[item['tipo']],
        notas: item['notas'],
        esFavorito: item['esFavorito'] ?? false,
        fechaCreacion: DateTime.parse(item['fechaCreacion']),
      );
    }

    await _personajesBox.putAll(paraGuardar);

    for (final imagenAnterior in imagenesAnteriores) {
      await FileService.eliminarImagenLocal(imagenAnterior);
    }

    if (await resultado.directorioExtraido.exists()) {
      await resultado.directorioExtraido.delete(recursive: true);
    }

    _cargarPersonajes();
    await FileService.limpiarImagenesHuerfanas(
      _personajes.map((personaje) => personaje.fotoPath),
    );
  }

  void _validarDatosImportados(Map<String, dynamic> item) {
    final tipo = item['tipo'];
    final fecha = item['fechaCreacion'];
    final fotoRelativa = item['fotoRelativa'];
    final rutaFotoValida = fotoRelativa == null ||
        (fotoRelativa is String &&
            fotoRelativa.startsWith('images/') &&
            path.basename(fotoRelativa) == fotoRelativa.substring('images/'.length));
    if (item['id'] is! String ||
        item['nombre'] is! String ||
        item['franquicia'] is! String ||
        tipo is! int ||
        tipo < 0 ||
        tipo >= TipoFranquicia.values.length ||
        fecha is! String ||
        DateTime.tryParse(fecha) == null ||
        !rutaFotoValida ||
        (item['notas'] != null && item['notas'] is! String) ||
        (item['esFavorito'] != null && item['esFavorito'] is! bool)) {
      throw Exception('El backup contiene una ficha con datos inválidos.');
    }
  }

  Future<void> descartarImportacion(ResultadoImportacion resultado) async {
    if (await resultado.directorioExtraido.exists()) {
      await resultado.directorioExtraido.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    if (Hive.isBoxOpen('personajes')) {
      _personajesBox.close();
    }
    super.dispose();
  }
}
