import 'package:flutter/material.dart';
import 'dart:io';
import '../models/personaje.dart';

class PersonajeCard extends StatelessWidget {
  final Personaje personaje;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorito;

  const PersonajeCard({
    super.key,
    required this.personaje,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorito,
  });

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Foto del personaje
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
                child: personaje.fotoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(personaje.fotoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 16),
              // Información del personaje
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            personaje.nombre,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (personaje.esFavorito)
                          Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      personaje.franquicia,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(
                        _getTipoTexto(personaje.tipo),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
              // Botones de acción
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                  IconButton(
                    icon: Icon(
                      personaje.esFavorito ? Icons.favorite : Icons.favorite_border,
                      color: personaje.esFavorito ? Colors.red : null,
                    ),
                    onPressed: onToggleFavorito,
                    tooltip: personaje.esFavorito ? 'Quitar favorito' : 'Añadir favorito',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
