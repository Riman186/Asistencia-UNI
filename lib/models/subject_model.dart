class SubjectModel {
  final String name;
  final String section;
  final String room;

  SubjectModel({
    required this.name,
    required this.section,
    required this.room,
  });

  // Método para convertir el objeto a Mapa (Necesario para guardar en Firebase)
  Map<String, dynamic> toMap() {
    return {
      'nombre': name,
      'seccion': section,
      'aula': room,
    };
  }

  // Útil para depuración o mostrar en logs
  @override
  String toString() {
    return "$name (Grupo: $section)";
  }
}