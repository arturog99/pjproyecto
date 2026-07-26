import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/personaje.dart';
import '../providers/personaje_provider.dart';
import '../services/file_service.dart';
import 'dart:io';

class DialogoEditarPersonaje extends StatefulWidget {
  final Personaje personaje;

  const DialogoEditarPersonaje({super.key, required this.personaje});

  @override
  State<DialogoEditarPersonaje> createState() => _DialogoEditarPersonajeState();
}

class _DialogoEditarPersonajeState extends State<DialogoEditarPersonaje> {
  late TextEditingController _nombreController;
  late TextEditingController _franquiciaController;
  late TextEditingController _notasController;
  String? _fotoPath;
  String? _fotoOriginal;
  late TipoFranquicia _tipoSeleccionado;
  bool _cargando = false;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.personaje.nombre);
    _franquiciaController = TextEditingController(text: widget.personaje.franquicia);
    _notasController = TextEditingController(text: widget.personaje.notas ?? '');
    _fotoPath = widget.personaje.fotoPath;
    _fotoOriginal = widget.personaje.fotoPath;
    _tipoSeleccionado = widget.personaje.tipo;
  }

  @override
  void dispose() {
    if (!_guardado && _fotoPath != _fotoOriginal) {
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

        final rutaLocal = await FileService.copiarImagenALocal(resultado.files.single.path!);

        if (_fotoPath != _fotoOriginal) {
          await FileService.eliminarImagenLocal(_fotoPath);
        }

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

  Future<void> _guardarCambios() async {
    if (_nombreController.text.trim().isEmpty || _franquiciaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa el nombre y la franquicia')),
      );
      return;
    }

    final provider = Provider.of<PersonajeProvider>(context, listen: false);

    final personajeActualizado = Personaje(
      id: widget.personaje.id,
      nombre: _nombreController.text.trim(),
      fotoPath: _fotoPath,
      franquicia: _franquiciaController.text.trim(),
      tipo: _tipoSeleccionado,
      notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
      esFavorito: widget.personaje.esFavorito,
      fechaCreacion: widget.personaje.fechaCreacion,
    );

    await provider.actualizarPersonaje(personajeActualizado);

    if (_fotoPath != _fotoOriginal && _fotoOriginal != null) {
      await FileService.eliminarImagenLocal(_fotoOriginal);
    }

    _guardado = true;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Personaje'),
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
          onPressed: _cargando ? null : _guardarCambios,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
          child: const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
