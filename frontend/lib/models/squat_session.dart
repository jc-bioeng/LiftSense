import 'package:hive/hive.dart';

// Generador de código para Hive a futuro (cuando usemos build_runner): part 'squat_session.g.dart';

@HiveType(typeId: 0)
class SquatSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double maxTrunkInclination; // Inclinación del tronco en el máximo descenso

  @HiveField(3)
  final double maxKneeFlexion; // Flexión máx de rodilla

  @HiveField(4)
  final double dynamicVelocity; // Velocidad relativa

  @HiveField(5)
  final String videoPath; // Referencia al video almacenado localmente

  SquatSession({
    required this.id,
    required this.date,
    required this.maxTrunkInclination,
    required this.maxKneeFlexion,
    required this.dynamicVelocity,
    this.videoPath = '',
  });
}

// Nota: No he incluido .g.dart temporalmente para no forzar ejecución de build_runner 
// hasta que el modelo esté blindado, nos comunicaremos en memoria para el inicio del mock.
