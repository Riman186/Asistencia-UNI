import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Para colores aleatorios

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  // Obtenemos el usuario actual
  final User? user = FirebaseAuth.instance.currentUser;

  // Paleta de colores para los cursos
  final List<Color> _avatarColors = [
    Colors.blue.shade700, Colors.orange.shade700, Colors.purple.shade700,
    Colors.teal.shade700, Colors.red.shade700, Colors.indigo.shade700,
    Colors.pink.shade700, Colors.green.shade700,
  ];

  // Obtener color basado en el nombre del curso
  Color _getColor(String courseName) {
    return _avatarColors[courseName.length % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Mi Historial Académico", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade900,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(child: Text("No hay sesión activa"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('asistencias')
                  .where('alumnoId', isEqualTo: user!.uid)
                  // NOTA: Quitamos el orderBy aquí para evitar el error de índice
                  .snapshots(),
              builder: (context, snapshot) {
                // 1. Carga
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Error
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }

                // 3. Vacío
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text("Aún no tienes asistencias registradas.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                // 4. ORDENAMIENTO MANUAL (CLIENT-SIDE)
                // Convertimos a lista y ordenamos por fecha descendente (más reciente primero)
                List<QueryDocumentSnapshot> docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
                  final Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
                  
                  // Obtenemos los timestamps (manejamos nulos por seguridad)
                  final Timestamp tA = dataA['timestamp'] ?? Timestamp.now();
                  final Timestamp tB = dataB['timestamp'] ?? Timestamp.now();
                  
                  // Orden Descendente: B comparado con A
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    // Extraer datos
                    final curso = data['curso'] ?? 'Curso Desconocido';
                    final fecha = data['fecha'] ?? '--/--/----';
                    final hora = data['hora_registro'] ?? '--:--';
                    final aula = data['aula'] ?? 'S/A';
                    final estado = data['estado'] ?? 'Presente';
                    
                    final color = _getColor(curso);
                    final isLastItem = index == docs.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- COLUMNA DE TIEMPO (Izquierda) ---
                          SizedBox(
                            width: 50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(hora.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(hora.split(' ').length > 1 ? hora.split(' ')[1] : '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // --- LÍNEA DE TIEMPO (Centro) ---
                          Column(
                            children: [
                              // Nodo (Círculo)
                              Container(
                                width: 14, 
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)]
                                ),
                              ),
                              // Línea conectora
                              if (!isLastItem)
                                Expanded(
                                  child: Container(
                                    width: 2, 
                                    color: Colors.grey.shade200,
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 15),

                          // --- TARJETA DE DETALLE (Derecha) ---
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20), // Espacio entre tarjetas
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Fila Superior: Nombre y Estado
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            curso, 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                            maxLines: 1, 
                                            overflow: TextOverflow.ellipsis
                                          ),
                                        ),
                                        _buildStatusBadge(estado),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Fila Inferior: Iconos y Detalles
                                    Row(
                                      children: [
                                        // Fecha
                                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text(fecha, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        
                                        const SizedBox(width: 15),
                                        
                                        // Aula
                                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
                                        const SizedBox(width: 4),
                                        Text("Aula $aula", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  // Widget auxiliar para la etiqueta de estado
  Widget _buildStatusBadge(String status) {
    Color bgColor = Colors.green.shade50;
    Color textColor = Colors.green.shade700;
    Color borderColor = Colors.green.shade100;

    if (status.toLowerCase().contains("tarde")) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      borderColor = Colors.orange.shade100;
    } else if (status.toLowerCase().contains("falta") || status.toLowerCase().contains("ausente")) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade800;
      borderColor = Colors.red.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}