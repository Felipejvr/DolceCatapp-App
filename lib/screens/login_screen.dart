import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _iniciarSesion() async {
    print("DEBUG: Iniciando proceso de login...");
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
      print("DEBUG: Campos vacíos");
      

    setState(() => _isLoading = true);

    try {
      print("DEBUG: Llamando a signInWithEmailAndPassword..."); // <-- LOG 2
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      print("DEBUG: Login exitoso"); // <-- LOG 3
      // Si tiene éxito, el StreamBuilder en main.dart detectará el cambio y cambiará de pantalla automáticamente.
    } on FirebaseAuthException catch (e) {
      print("DEBUG: Error de Firebase: ${e.code} - ${e.message}"); // <-- LOG 4
      setState(() => _isLoading = false);
      String mensaje = "Error al iniciar sesión";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensaje = "Correo o contraseña incorrectos.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F0), // Fondo pastel de tu app
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cake, size: 80, color: Color(0xFFD98A7A)),
              const SizedBox(height: 20),
              const Text("DolceCatapp", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFD98A7A))),
              const SizedBox(height: 10),
              const Text("Acceso exclusivo para el equipo", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: "Correo electrónico", prefixIcon: Icon(Icons.email, color: Color(0xFFD98A7A)), border: InputBorder.none, contentPadding: EdgeInsets.all(15)),
                ),
              ),
              const SizedBox(height: 15),
              
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: TextField(
                  controller: _passCtrl,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    hintText: "Contraseña", 
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFD98A7A)), 
                    border: InputBorder.none, 
                    contentPadding: const EdgeInsets.all(15),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              _isLoading 
                ? const CircularProgressIndicator(color: Color(0xFFD98A7A))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD98A7A), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: _iniciarSesion,
                    child: const Text("Ingresar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}