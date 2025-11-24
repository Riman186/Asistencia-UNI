import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject_model.dart';
import 'teacher_login_screen.dart'; // Importamos el Login para ir allí al finalizar

class TeacherStep2Screen extends StatefulWidget {
  final String name;
  final String employeeId;
  final String email;
  final String password;
  final List<SubjectModel> subjects;

  const TeacherStep2Screen({
    super.key,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.password,
    required this.subjects,
  });

  @override
  State<TeacherStep2Screen> createState() => _TeacherStep2ScreenState();
}

class _TeacherStep2ScreenState extends State<TeacherStep2Screen> {
  bool _isLoading = false;

  // Días y Horas (7 AM a 8 PM)
  final List<String> _days = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
  final List<String> _hours = [
    "07:00", "08:00", "09:00", "10:00", "11:00", "12:00", 
    "13:00", "14:00", "15:00", "16:00", "17:00", "18:00", "19:00", "20:00"
  ];

  // MATRIZ DE HORARIO: _schedule[Día][Hora] = Asignatura
  // Usamos un Map anidado para acceso rápido
  final Map<String, Map<String, SubjectModel?>> _schedule = {};

  @override
  void initState() {
    super.initState();
    // Inicializamos la matriz vacía
    for (var day in _days) {
      _schedule[day] = {};
      for (var hour in _hours) {
        _schedule[day]![hour] = null;
      }
    }
  }

  // --- LÓGICA DE SELECCIÓN DE CLASE ---
  void _showClassSelectionDialog(String day, String hour) {
    SubjectModel? selectedSubject;
    String? selectedName; // Para el primer filtro (Nombre único)

    // 1. Obtener nombres únicos de materias para el primer dropdown
    final uniqueNames = widget.subjects.map((e) => e.name).toSet().toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Necesario para actualizar el dropdown interno
          builder: (context, setModalState) {
            // 2. Filtrar secciones disponibles según el nombre seleccionado
            List<SubjectModel> availableSections = [];
            if (selectedName != null) {
              availableSections = widget.subjects.where((s) => s.name == selectedName).toList();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Text("$day - $hour", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 5),
                  const Text("Asignar Clase", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DROPDOWN 1: NOMBRE DEL CURSO
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Materia",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.book),
                    ),
                    initialValue: selectedName,
                    items: uniqueNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedName = val;
                        selectedSubject = null; // Resetear sección al cambiar materia
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // DROPDOWN 2: SECCIÓN / GRUPO (Solo aparece si eligió materia)
                  if (selectedName != null)
                    DropdownButtonFormField<SubjectModel>(
                      decoration: InputDecoration(
                        labelText: "Sección / Grupo",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.group),
                      ),
                      initialValue: selectedSubject,
                      items: availableSections.map((subject) {
                        return DropdownMenuItem(
                          value: subject,
                          child: Text("Grupo: ${subject.section} (${subject.room})"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => selectedSubject = val);
                      },
                    ),
                ],
              ),
              actions: [
                // Opción de Borrar (Si ya había algo asignado)
                if (_schedule[day]![hour] != null)
                  TextButton(
                    onPressed: () {
                      setState(() => _schedule[day]![hour] = null);
                      Navigator.pop(context);
                    },
                    child: const Text("Borrar", style: TextStyle(color: Colors.red)),
                  ),
                
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                
                ElevatedButton(
                  onPressed: selectedSubject == null ? null : () {
                    setState(() {
                      _schedule[day]![hour] = selectedSubject;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  child: const Text("Asignar"),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- GUARDAR EN FIREBASE ---
  Future<void> _finishRegister() async {
    setState(() => _isLoading = true);

    try {
      // 1. Convertir la matriz _schedule en una Lista plana para Firebase
      List<Map<String, dynamic>> flatSchedule = [];
      
      _schedule.forEach((day, hoursMap) {
        hoursMap.forEach((hour, subject) {
          if (subject != null) {
            flatSchedule.add({
              'curso': subject.name,
              'seccion': subject.section,
              'aula': subject.room,
              'dia': day,
              'hora': _formatHourAMPM(hour), // Guardamos como "07:00 AM"
            });
          }
        });
      });

      // Validación: Al menos 1 clase asignada
      if (flatSchedule.isEmpty) {
        throw Exception("Debes asignar al menos una clase en el horario.");
      }

      // 2. Crear Auth
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      // 3. Guardar en Firestore
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'role': 'teacher',
        'nombre_completo': widget.name,
        'codigo_docente': widget.employeeId,
        'email': widget.email,
        'cursos_impartidos': widget.subjects.map((s) => s.toMap()).toList(),
        'horario': flatSchedule,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Registro completado!"), backgroundColor: Colors.green)
      );

      // 4. IR AL LOGIN (Como pediste)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const TeacherLoginScreen()),
        (route) => false,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatHourAMPM(String hour24) {
    int h = int.parse(hour24.split(":")[0]);
    String suffix = h >= 12 ? "PM" : "AM";
    int h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$h12:00 $suffix";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // --- HEADER ---
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade900,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: const SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text("Arma tu Horario", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Toca una casilla para asignar", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),

          // --- GRID DE HORARIO ---
          Expanded(
            child: SingleChildScrollView( // Scroll Vertical
              child: SingleChildScrollView( // Scroll Horizontal
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(100), // Ancho de cada columna de día
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      // FILA DE ENCABEZADO (DÍAS)
                      TableRow(
                        decoration: BoxDecoration(color: Colors.blue.shade50),
                        children: [
                          // Celda vacía (esquina sup izq)
                          const SizedBox(width: 60, height: 40), 
                          ..._days.map((day) => Container(
                            height: 40,
                            alignment: Alignment.center,
                            child: Text(day.substring(0, 3), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                          )),
                        ],
                      ),

                      // FILAS DE HORAS
                      ..._hours.map((hour) {
                        return TableRow(
                          children: [
                            // COLUMNA DE HORAS (Eje Y)
                            Container(
                              width: 60,
                              height: 70, // Altura de cada celda
                              alignment: Alignment.center,
                              color: Colors.grey.shade100,
                              child: Text(hour, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            
                            // CELDAS INTERACTIVAS (Días)
                            ..._days.map((day) {
                              final subject = _schedule[day]![hour];
                              final isOccupied = subject != null;

                              return InkWell(
                                onTap: () => _showClassSelectionDialog(day, hour),
                                child: Container(
                                  height: 70,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isOccupied ? Colors.blue.shade100 : Colors.white,
                                    border: Border.all(color: Colors.grey.shade100),
                                  ),
                                  alignment: Alignment.center,
                                  child: isOccupied 
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(subject.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                          Text("Aula ${subject.room}", style: const TextStyle(fontSize: 9)),
                                        ],
                                      )
                                    : const Icon(Icons.add, size: 16, color: Colors.grey),
                                ),
                              );
                            })
                          ],
                        );
                      })
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // --- BOTÓN FLOTANTE FINALIZAR ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white, 
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
        ),
        child: SizedBox(
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _finishRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("FINALIZAR Y GUARDAR HORARIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}