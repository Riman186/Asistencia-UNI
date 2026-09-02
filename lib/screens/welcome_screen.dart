import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'teacher_login_screen.dart';
import 'student_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // El header ocupa una fracción del alto, pero acotada: sin el tope se
    // vuelve enorme en un monitor y deja sin espacio a un móvil en horizontal.
    final double headerHeight =
        (context.screenHeight * 0.45).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // --- HEADER CURVO CON GRADIENTE ---
                    Container(
                      height: headerHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade900, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(60),
                          bottomRight: Radius.circular(60),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade900.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo o Ícono Principal
                                Container(
                                  padding: EdgeInsets.all(
                                      context.isShort ? 14 : 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    size: context.isShort ? 52 : 80,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: context.isShort ? 12 : 20),
                                Text(
                                  "ASISTENCIA UNI",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: context.responsive(26,
                                        tablet: 30, desktop: 34),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Gestión Académica UNI 2025",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- SECCIÓN DE SELECCIÓN DE ROL ---
                    Expanded(
                      child: ResponsiveContainer(
                        maxWidth: Breakpoints.form,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsive(24.0, tablet: 30.0),
                          vertical: 30,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Selecciona tu perfil",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: context.isShort ? 20 : 30),

                            // TARJETA DOCENTE
                            _RoleCard(
                              title: "Soy Docente",
                              subtitle: "Gestión exclusiva para profesores",
                              icon: Icons.person_outline,
                              color: Colors.blue.shade800,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const TeacherLoginScreen()),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // TARJETA ESTUDIANTE
                            _RoleCard(
                              title: "Soy Estudiante",
                              subtitle: "Registro de asistencia para alumnos",
                              icon: Icons.school_outlined,
                              color: Colors.orange.shade700,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const StudentLoginScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- FOOTER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Text(
                        "Proyecto estudiantil UNI © 2025",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- WIDGET PRIVADO: TARJETA DE ROL ---
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Ícono Circular
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 20),
                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Flecha
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[300]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}