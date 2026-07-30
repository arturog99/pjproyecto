import 'package:flutter_test/flutter_test.dart';
import 'package:pjproyecto/models/personaje.dart';

void main() {
  test('Personaje conserva los datos de la ficha', () {
    final fecha = DateTime(2026, 7, 30);
    final personaje = Personaje(
      id: 'personaje-1',
      nombre: 'Leia Organa',
      franquicia: 'Star Wars',
      tipo: TipoFranquicia.pelicula,
      esFavorito: true,
      fechaCreacion: fecha,
    );

    expect(personaje.nombre, 'Leia Organa');
    expect(personaje.tipo, TipoFranquicia.pelicula);
    expect(personaje.esFavorito, isTrue);
    expect(personaje.fechaCreacion, fecha);
  });
}
