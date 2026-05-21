# DolceCatapp - Guía de Operaciones y Flujo de Trabajo
Este archivo contiene los comandos rápidos y el flujo de trabajo recomendado para la gestión de despliegue y desarrollo del proyecto.

# DolceCatapp

## 🚀 Despliegue en Firebase

### 1. Cambiar entorno (Dev/Prod)
En `lib/main.dart`, modifica la variable `isDevMode`:
```dart
const bool isDevMode = true;  // Usar base de datos de desarrollo
const bool isDevMode = false; // Usar base de datos de producción
```
#### Util
```bash
flutter clean // limpia todo
flutter pub get // reinstala lo limpiado
firebase use <project_name>
```
#### Crear firebase.json
```bash
flutterfire configure --project=dolcecatapp
```
#### Empaquetar aplicación por database
```bash
firebase use <project_name> // dolcecatapp or dolcecatapp-dev
flutter build web // empaqueta
firebase deploy --only hosting // lanza
```
#### Apagar sitio de prueba
```bash
firebase hosting:disable --project <project_name>
```
## 🌿 Flujo de Trabajo con Git
Para mantener la rama main limpia y segura, utiliza el siguiente flujo basado en ramas de características (feature branches):

### 1. Guardar cambios

#### Una vez hechos los cambios:
```bash
git add .
git commit -m "Descripción clara de lo que hiciste"
```
#### Actualizar el proyecto (Sincronización):
Asegúrate de tener lo último de main antes de integrar:
```bash
git checkout main
git pull origin main
git checkout feature/nombre-de-tu-tarea
git merge main
```
#### Integrar cambios a main:
Una vez verificado que todo funciona correctamente:
```bash
git checkout main
git merge feature/nombre-de-tu-tarea
git push origin main
```
#### Elimina la rama local una vez integrada:

```bash
git branch -d feature/nombre-de-tu-tarea
```
## Notas adicionales
Asegúrate siempre de haber ejecutado flutter build web antes de cada firebase deploy.

Nunca realices commits directamente sobre main a menos que sea una corrección crítica o un "hotfix" menor.
