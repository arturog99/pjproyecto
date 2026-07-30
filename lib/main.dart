import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'providers/personaje_provider.dart';
import 'models/personaje.dart';
import 'widgets/personaje_card.dart';
import 'widgets/dialogo_editar_personaje.dart';
import 'widgets/vista_detalle_personaje.dart';
import 'services/file_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Limita la caché de bitmaps para que navegar por muchas fichas no haga
  // crecer indefinidamente el consumo de memoria.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;
  
  await Hive.initFlutter();
  Hive.registerAdapter(TipoFranquiciaAdapter());
  Hive.registerAdapter(PersonajeAdapter());
  
  runApp(const PersonajesApp());
}

class PersonajesApp extends StatelessWidget {
  const PersonajesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PersonajeProvider(),
      child: MaterialApp(
        title: 'El imperio romano de cori',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F3FF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC8B6FF),
            secondary: Color(0xFFA3B18A),
            surface: Color(0xFFF5F3FF),
            tertiary: Color(0xFFD4E4D4),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            color: const Color(0xFFE8E4FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFDCD0FF),
            foregroundColor: Colors.black87,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFB8D4B8),
            foregroundColor: Colors.white,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFFD4E4D4),
            selectedColor: const Color(0xFFC8B6FF),
            labelStyle: const TextStyle(color: Colors.black87),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB8A9C9),
            secondary: Color(0xFF6B8E6B),
            surface: Color(0xFF1A1A2E),
            tertiary: Color(0xFF4A5A4A),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            color: const Color(0xFF2D2D4A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2D2D4A),
            foregroundColor: Color(0xFFB8A9C9),
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF6B8E6B),
            foregroundColor: Colors.white,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFF4A5A4A),
            selectedColor: const Color(0xFFB8A9C9),
            labelStyle: const TextStyle(color: Colors.white),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const PantallaPrincipal(),
      ),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _abrirDialogoAnadir() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const DialogoAnadirPersonaje();
      },
    );
  }

  Future<void> _confirmarEliminacion(
    Personaje personaje,
    PersonajeProvider provider,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Personaje'),
          content: Text('¿Estás seguro de que quieres eliminar a ${personaje.nombre}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await provider.eliminarPersonaje(personaje);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportarDatos(PersonajeProvider provider) async {
    try {
      final nombreSugerido = 'personajes_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

      final rutaDestino = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar backup de personajes',
        fileName: nombreSugerido,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (rutaDestino == null) return;

      await provider.exportarDatos(rutaDestino);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado en: $rutaDestino')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _importarDatos(PersonajeProvider provider) async {
    ResultadoImportacion? analisis;
    try {
      final resultadoArchivo = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (resultadoArchivo == null || resultadoArchivo.files.single.path == null) return;

      analisis = await provider.analizarImportacion(resultadoArchivo.files.single.path!);

      if (!mounted) return;

      bool sobrescribir = false;
      if (analisis.duplicados > 0) {
        final opcion = await _mostrarDialogoConflictos(analisis);
        if (opcion == null) return;
        sobrescribir = opcion;
      }

      await provider.confirmarImportacion(analisis, sobrescribirDuplicados: sobrescribir);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos importados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    } finally {
      if (analisis != null) {
        await provider.descartarImportacion(analisis);
      }
    }
  }

  Future<bool?> _mostrarDialogoConflictos(ResultadoImportacion analisis) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflictos al importar'),
        content: Text(
          'Se encontraron ${analisis.duplicados} personaje(s) que ya existen '
          '(${analisis.nuevos} son nuevos).\n\n'
          '¿Qué quieres hacer con los duplicados?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mantener actuales'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sobrescribir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonajeProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('El imperio romano de cori 💖'),
            actions: [
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: provider.estaCargando || provider.errorCarga != null
                    ? null
                    : () => _exportarDatos(provider),
                tooltip: 'Exportar datos',
              ),
              IconButton(
                icon: const Icon(Icons.file_download),
                onPressed: provider.estaCargando || provider.errorCarga != null
                    ? null
                    : () => _importarDatos(provider),
                tooltip: 'Importar datos',
              ),
              PopupMenuButton<String>(
                enabled: !provider.estaCargando && provider.errorCarga == null,
                onSelected: (opcion) {
                  if (opcion == 'nombre') {
                    provider.ordenarPorNombre();
                  } else if (opcion == 'fecha') {
                    provider.ordenarPorFecha();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'nombre',
                    child: Text('Ordenar por nombre'),
                  ),
                  const PopupMenuItem(
                    value: 'fecha',
                    child: Text('Ordenar por fecha'),
                  ),
                ],
              ),
            ],
          ),
          body: provider.estaCargando
              ? const Center(child: CircularProgressIndicator())
              : provider.errorCarga != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      provider.errorCarga!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
            children: [
              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _busquedaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o franquicia...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busquedaController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busquedaController.clear();
                              provider.setBusqueda('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (valor) {
                    provider.setBusqueda(valor);
                  },
                ),
              ),
              // Filtros por tipo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: provider.filtroTipo == null,
                        onSelected: (selected) {
                          provider.setFiltroTipo(null);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Series'),
                        selected: provider.filtroTipo == TipoFranquicia.serie,
                        onSelected: (selected) {
                          provider.setFiltroTipo(TipoFranquicia.serie);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Películas'),
                        selected: provider.filtroTipo == TipoFranquicia.pelicula,
                        onSelected: (selected) {
                          provider.setFiltroTipo(TipoFranquicia.pelicula);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Libros'),
                        selected: provider.filtroTipo == TipoFranquicia.libro,
                        onSelected: (selected) {
                          provider.setFiltroTipo(TipoFranquicia.libro);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Favoritos'),
                        avatar: Icon(
                          provider.soloFavoritos ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: provider.soloFavoritos ? Colors.red : null,
                        ),
                        selected: provider.soloFavoritos,
                        onSelected: (selected) {
                          provider.setSoloFavoritos(selected);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Lista de personajes
              Expanded(
                child: provider.personajes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.todosPersonajes.isEmpty
                                  ? 'Aún no hay personajes. ¡Añade el primero!'
                                  : 'No se encontraron personajes',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.personajes.length,
                        itemBuilder: (context, index) {
                          final personaje = provider.personajes[index];
                          return PersonajeCard(
                            key: ValueKey(personaje.id),
                            personaje: personaje,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VistaDetallePersonaje(personaje: personaje),
                                ),
                              );
                            },
                            onEdit: () {
                              showDialog(
                                context: context,
                                builder: (context) => DialogoEditarPersonaje(personaje: personaje),
                              );
                            },
                            onDelete: () {
                              _confirmarEliminacion(personaje, provider);
                            },
                            onToggleFavorito: () {
                              provider.toggleFavorito(personaje);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: provider.estaCargando || provider.errorCarga != null
                ? null
                : _abrirDialogoAnadir,
            tooltip: 'Añadir personaje',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

// --- NUEVO: Clase que maneja el formulario de la ventana emergente ---
class DialogoAnadirPersonaje extends StatefulWidget {
  const DialogoAnadirPersonaje({super.key});

  @override
  State<DialogoAnadirPersonaje> createState() => _DialogoAnadirPersonajeState();
}

class _DialogoAnadirPersonajeState extends State<DialogoAnadirPersonaje> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _franquiciaController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  String? _fotoPath;
  TipoFranquicia _tipoSeleccionado = TipoFranquicia.serie;
  bool _cargando = false;
  bool _guardado = false;

  @override
  void dispose() {
    if (!_guardado && _fotoPath != null) {
      FileService.eliminarImagenLocal(_fotoPath);
    }
    _nombreController.dispose();
    _franquiciaController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (resultado != null && resultado.files.single.path != null) {
        setState(() {
          _cargando = true;
        });

        if (_fotoPath != null) {
          await FileService.eliminarImagenLocal(_fotoPath);
        }

        final rutaLocal = await FileService.copiarImagenALocal(resultado.files.single.path!);

        setState(() {
          _fotoPath = rutaLocal;
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _cargando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar foto: $e')),
        );
      }
    }
  }

  Future<void> _guardarPersonaje() async {
    if (_nombreController.text.trim().isEmpty || _franquiciaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa el nombre y la franquicia')),
      );
      return;
    }

    final provider = Provider.of<PersonajeProvider>(context, listen: false);

    final personaje = Personaje(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: _nombreController.text.trim(),
      fotoPath: _fotoPath,
      franquicia: _franquiciaController.text.trim(),
      tipo: _tipoSeleccionado,
      notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      fechaCreacion: DateTime.now(),
    );

    await provider.agregarPersonaje(personaje);

    _guardado = true;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Personaje'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del personaje',
                hintText: 'Ej. Harry Potter',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _franquiciaController,
              decoration: const InputDecoration(
                labelText: 'Serie, Película o Libro',
                hintText: 'Ej. Harry Potter y la Piedra Filosofal',
                prefixIcon: Icon(Icons.movie),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoFranquicia>(
              value: _tipoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: TipoFranquicia.serie, child: Text('Serie')),
                DropdownMenuItem(value: TipoFranquicia.pelicula, child: Text('Película')),
                DropdownMenuItem(value: TipoFranquicia.libro, child: Text('Libro')),
              ],
              onChanged: (valor) {
                setState(() {
                  _tipoSeleccionado = valor!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notasController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Añade detalles adicionales...',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cargando ? null : _seleccionarFoto,
              icon: _cargando 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image),
              label: Text(_fotoPath != null ? 'Cambiar Foto' : 'Seleccionar Foto'),
            ),
            if (_fotoPath != null) ...[
              const SizedBox(height: 8),
              const Text('Foto seleccionada ✓', style: TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _cargando ? null : _guardarPersonaje,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
