# Laboratorio: pipeline de CI con GitHub Actions en una API Laravel

[![CI Laravel](https://github.com/DweskZ/laboratorio-ci-laravel/actions/workflows/ci.yml/badge.svg)](https://github.com/DweskZ/laboratorio-ci-laravel/actions/workflows/ci.yml)

Curso IS-803, grupo 04.

## Propósito

Demostrar cómo un pipeline de integración continua (CI) en GitHub Actions
verifica automáticamente un backend Laravel en cada `push` y `pull_request`:
instala dependencias, valida la sintaxis, prepara el entorno, ejecuta las
pruebas y construye una imagen Docker. El proyecto expone un único endpoint,
`GET /api/health`, con una prueba de característica asociada.

## Réplica rápida (sin instalar nada)

Solo se necesita un navegador y una cuenta de GitHub.

1. En la página del repositorio, pulsar **Use this template** >
   **Create a new repository** y crear la copia en la cuenta propia.
2. Abrir la pestaña **Actions** de la copia: la primera ejecución de
   "CI Laravel" se inicia sola y debe terminar en verde.
3. Abrir `tests/Feature/HealthTest.php`, pulsar el lápiz (**Edit this file**)
   y cambiar `'ok'` por `'fallo'` en `assertJson`.
4. En **Commit changes**, elegir **Create a new branch for this commit and
   start a pull request** y crear el pull request.
5. Observar la verificación en rojo dentro del pull request y abrir el log
   del paso "Ejecutar pruebas".
6. En la misma rama, editar de nuevo el archivo, restaurar `'ok'` y
   confirmar el cambio: la verificación vuelve a verde.

## Requisitos previos

- Git instalado.
- Cuenta de GitHub.
- PHP 8.3 o superior.
- Composer 2.

## Pasos guiados

### 1. Crear o usar un repositorio Git del backend, sin `.env` ni claves

```bash
git clone https://github.com/<usuario>/<repositorio>.git
cd <repositorio>
```

Si se parte de este proyecto sin remoto:

```bash
git remote add origin https://github.com/<usuario>/<repositorio>.git
```

Verificar que `.env` está ignorado y no versionado:

```bash
git check-ignore .env      # debe imprimir ".env"
git ls-files | grep -c '^\.env$'   # debe imprimir 0
```

### 2. Lograr que las pruebas pasen en local

```bash
composer install
cp .env.example .env
php artisan key:generate
php artisan test
```

El resultado esperado es una prueba en verde (`HealthTest`). Las pruebas
usan SQLite en memoria (definido en `phpunit.xml`), por lo que no requieren
una base de datos real.

### 3. Crear el workflow `.github/workflows/ci.yml`

El archivo debe estar exactamente en `.github/workflows/` y declarar los
disparadores `push` y `pull_request`:

```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
```

- `push` a `main`: verifica lo que ya se integró.
- `pull_request`: verifica el cambio antes de integrarlo.
- `workflow_dispatch`: agrega el botón **Run workflow** en la pestaña
  **Actions** para ejecutar el pipeline a mano, sin hacer un commit.

### 4. Definir los jobs en ubuntu-latest

El job `verificar` se ejecuta en `ubuntu-latest` y realiza, en orden:

1. Obtener el código (`actions/checkout@v7`).
2. Configurar PHP 8.3 (`shivammathur/setup-php@v2`).
3. Restaurar la caché de Composer (`actions/cache@v6`) para acelerar la
   instalación en ejecuciones posteriores.
4. Instalar dependencias con Composer.
5. Validar la sintaxis de los archivos PHP.
6. Copiar `.env.example` a `.env` y generar `APP_KEY`.
7. Ejecutar `php artisan test`.

El job `construir` solo se ejecuta si `verificar` termina bien
(`needs: verificar`):

1. Construye la imagen Docker definida en `Dockerfile`.
2. Levanta un contenedor y consulta `GET /api/health` para confirmar que la
   imagen funciona. La `APP_KEY` se genera en ese momento y se pasa como
   variable de entorno; no queda guardada en la imagen.

Para probar la imagen en local:

```bash
docker build -t laboratorio-ci-laravel .
docker run --rm -p 8000:8000 \
  -e APP_KEY="base64:$(openssl rand -base64 32)" laboratorio-ci-laravel
curl http://localhost:8000/api/health
```

### 5. Subir un cambio y revisar la pestaña Actions

```bash
git add .
git commit -m "ci: add GitHub Actions workflow"
git push -u origin main
```

En GitHub, abrir la pestaña **Actions** del repositorio, seleccionar la
ejecución más reciente de "CI Laravel" y revisar el estado del job
`verificar` y el log de cada paso.

### 6. Provocar un fallo controlado, corregirlo y volver a verde

En `tests/Feature/HealthTest.php`, cambiar la aserción:

```php
$response->assertJson(['status' => 'fallo']);
```

Confirmar el fallo en local y publicarlo en una rama con un pull request:

```bash
php artisan test            # termina con código distinto de cero
git switch -c demo/fallo-controlado
git commit -am "test: break health assertion on purpose"
git push -u origin demo/fallo-controlado
gh pr create --fill         # o abrir el pull request desde la web
```

La verificación aparece en rojo dentro del pull request: el error se detecta
antes de llegar a `main`. Revisar el log del paso "Ejecutar pruebas"; el job
`construir` no se ejecuta porque depende de `verificar`. Para corregirlo,
restaurar `'ok'`:

```bash
git commit -am "fix: restore health assertion"
git push
```

La verificación del pull request vuelve a verde.

## Errores frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `composer install` falla en CI con "requires php >= 8.4" | `composer.lock` generado con una versión de PHP local más nueva que la del CI | Mantener `config.platform.php` en `composer.json` (aquí `8.3.0`) y ejecutar `composer update` para regenerar el lock |
| "No application encryption key has been specified" | Falta `.env` o `APP_KEY` | Ejecutar `cp .env.example .env` y `php artisan key:generate` |
| El workflow no aparece en Actions o marca error de sintaxis | Archivo fuera de `.github/workflows/` o indentación YAML incorrecta (usar espacios, no tabulaciones) | Verificar la ruta exacta y validar la indentación |
| Las pruebas pasan en local pero fallan en CI | Diferencias de versión de PHP, dependencia de `.env` local, de una base de datos o de archivos no versionados | Reproducir con la misma versión de PHP, clonar el repositorio en limpio y revisar el log del paso fallido |

## Lista de verificación de seguridad

- [ ] `.env` no está versionado (figura en `.gitignore`).
- [ ] No hay claves, tokens ni contraseñas en el repositorio ni en `.env.example`.
- [ ] Se revisan los logs de Actions antes de compartirlos o hacerlos públicos.
- [ ] Las credenciales reales se almacenan en GitHub Secrets
      (Settings > Secrets and variables > Actions), nunca en el código.
