DolceCatapp - Guía de Operaciones y Flujo de Trabajo
Este archivo contiene los comandos rápidos y el flujo de trabajo recomendado para la gestión de despliegue y desarrollo del proyecto.

🚀 Despliegue en Firebase Hosting
Para realizar despliegues rápidos a producción o pruebas:

Cambiar entre entornos (Dev/Prod):
Edita el archivo lib/main.dart:

Dart
const bool isDevMode = true;  // Usar base de datos de desarrollo
const bool isDevMode = false; // Usar base de datos de producción
Seleccionar proyecto actual:

Bash
firebase use <nombre_del_proyecto>
Empaquetar la aplicación:

Bash
flutter build web
Lanzar la aplicación:

Bash
firebase deploy --only hosting
Apagar sitio (prueba):

Bash
firebase hosting:disable --project <nombre_del_proyecto>
🌿 Flujo de Trabajo con Git
Para mantener la rama main limpia y segura, utiliza el siguiente flujo basado en ramas de características (feature branches):

Crear una rama nueva para cambios:
Antes de empezar cualquier tarea, crea una rama específica:

Bash
git checkout -b feature/nombre-de-tu-tarea
Trabajar y guardar cambios:
Una vez hechos los cambios:

Bash
git add .
git commit -m "Descripción clara de lo que hiciste"
Actualizar el proyecto (Sincronización):
Asegúrate de tener lo último de main antes de integrar:

Bash
git checkout main
git pull origin main
git checkout feature/nombre-de-tu-tarea
git merge main
Integrar cambios a main:
Una vez verificado que todo funciona correctamente:

Bash
git checkout main
git merge feature/nombre-de-tu-tarea
git push origin main
Limpieza:
Elimina la rama local una vez integrada:

Bash
git branch -d feature/nombre-de-tu-tarea
Notas adicionales
Asegúrate siempre de haber ejecutado flutter build web antes de cada firebase deploy.

Nunca realices commits directamente sobre main a menos que sea una corrección crítica o un "hotfix" menor.
