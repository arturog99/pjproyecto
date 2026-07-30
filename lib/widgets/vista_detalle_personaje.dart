import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/personaje.dart';
import '../providers/personaje_provider.dart';
import 'dialogo_editar_personaje.dart';

class VistaDetallePersonaje extends StatelessWidget {
  final Personaje personaje;

  const VistaDetallePersonaje({super.key, required this.personaje});

  String _getTipoTexto(TipoFranquicia tipo) {
    switch (tipo) {
      case TipoFranquicia.serie:
        return 'Serie';
      case TipoFranquicia.pelicula:
        return 'Película';
      case TipoFranquicia.libro:
        return 'Libro';
    }
  }

  Future<void> _confirmarEliminacion(
    BuildContext context,
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
                if (!context.mounted) return;
                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.of(context).pop(); // Cerrar vista detalle
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(personaje.nombre),
        actions: [
          IconButton(
            icon: Icon(
              personaje.esFavorito ? Icons.favorite : Icons.favorite_border,
              color: personaje.esFavorito ? Colors.red : null,
            ),
            onPressed: () {
              Provider.of<PersonajeProvider>(context, listen: false)
                  .toggleFavorito(personaje);
            },
            tooltip: personaje.esFavorito ? 'Quitar favorito' : 'Añadir favorito',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => DialogoEditarPersonaje(personaje: personaje),
              );
            },
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              final provider = Provider.of<PersonajeProvider>(context, listen: false);
              _confirmarEliminacion(context, provider);
            },
            tooltip: 'Eliminar',
            color: Colors.red,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto grande del personaje
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
                child: personaje.fotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(personaje.fotoPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          cacheHeight: 400,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Nombre
            Text(
              personaje.nombre,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            
            // Franquicia
            Row(
              children: [
                Icon(
                  Icons.movie,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  personaje.franquicia,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Tipo
            Chip(
              label: Text(_getTipoTexto(personaje.tipo)),
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              avatar: Icon(
                Icons.category,
                size: 18,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Fecha de creación
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Añadido el ${_formatDate(personaje.fechaCreacion)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Notas
            if (personaje.notas != null && personaje.notas!.isNotEmpty) ...[
              Text(
                'Notas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  personaje.notas!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Sin notas adicionales',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
