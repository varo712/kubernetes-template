# Nombre del Proyecto

Descripción breve del proyecto. Reemplazar por el propósito real del repositorio.

## Requisitos

- [`mise`](https://mise.jdx.dev/) instalado. El resto de herramientas (`pre-commit`, `sops`, `age`, `kubectl`, `helm`, `flux`, `flux-operator`, `kustomize`, `kubeconform`) las gestiona mise, no hace falta instalarlas a mano.

Instalación de mise:

**Linux**

```sh
curl https://mise.run | sh
```

Luego activa mise en tu shell (añade la línea a `~/.bashrc`, `~/.zshrc`, etc.):

```sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc   # bash
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc     # zsh
```

También disponible vía `apt`, `dnf`, `pacman`, `apk`, etc. — ver la [guía oficial](https://mise.jdx.dev/installing-mise.html).

**macOS**

```sh
brew install mise
```

o con el mismo script que Linux (`curl https://mise.run | sh` + activar en el shell).

**Windows**

```powershell
winget install jdx.mise
```

Alternativas: `scoop install mise` / `choco install mise`.

Más detalles en la [guía oficial de instalación](https://mise.jdx.dev/installing-mise.html).

## Primeros pasos

```
mise run init
```

Deja el entorno listo para trabajar:

- Instala los hooks de pre-commit.
- Genera una clave age en `~/.config/sops/age/keys.txt` **si no tienes una ya** (si ya tienes una, por ejemplo de otro proyecto, la reutiliza en vez de sobrescribirla) y mete su public key en las reglas del equipo de `.sops.yaml` (`dev`, `preprod` y `local`, nunca `prod`).
- Instala los plugins de helm `diff` y `secrets` (si no están instalados ya).
- Si quedan valores `REEMPLAZAME`, pregunta los del proyecto (ver `mise run configure`). Sin terminal interactiva, se omite y hay que ejecutar esa tarea después.

Si prefieres usar una clave age propia en vez de que se genere una nueva, pon tu `keys.txt` en `~/.config/sops/age/keys.txt` *antes* de correr `mise run init` — la detecta y la reutiliza.

## Estructura

Monorepo con rama única `main` y una carpeta por entorno (`dev`, `preprod`, `prod`):

```text
clusters/<env>/          # Lo que sincroniza cada cluster: FluxInstance y Kustomizations
infrastructure/base/     # Componentes de cluster comunes (incluye Flux Operator)
infrastructure/<env>/    # Overlay de infraestructura: versiones por entorno
apps/base/               # Aplicaciones comunes (podinfo es un ejemplo: sustitúyelo)
apps/<env>/              # Overlay de aplicaciones: versión y values por entorno
local/                   # Opcional: values cifrados para usar a mano con helm secrets
scripts/                 # Scripts de las tareas de mise (ejecútalos con mise run)
```

**`base` afecta a todos los entornos a la vez.** Lo que deba promocionarse va en un chart versionado, no en `base`.

## Poner en marcha un cluster

1. Rellena los valores del proyecto, si `mise run init` no lo hizo ya. Para cambiarlos después, vuelve a ejecutar la tarea:

   ```sh
   mise run configure
   ```

2. Genera la clave del cluster:

   ```sh
   mise run flux-keygen -- <env>
   ```

   Guarda `~/.config/sops/age/projects/<proyecto>/clusters/<env>.txt` en un gestor de secretos. Si se pierde, no podrás descifrar los secretos de ese entorno.
3. Solo para `prod`, añade la clave de los administradores (sin ella, no se puede cifrar para `prod`):

   ```sh
   mise run add-recipient -- prod <age1...>
   ```

4. Haz commit y push a `main`. Flux lee `clusters/<env>` del remoto.
5. Instala Flux con credenciales de **solo lectura** del repositorio, según el protocolo elegido:

   ```sh
   GIT_TOKEN=<token> mise run flux-bootstrap -- <env> <kube-context>            # https
   GIT_SSH_KEY_FILE=<clave> mise run flux-bootstrap -- <env> <kube-context>     # ssh
   ```

   En SSH, la clave privada no debe tener contraseña y su pública debe estar registrada como deploy key.

   El usuario de HTTPS es `git` por defecto. Si tu servidor exige otro, defínelo con `GIT_USERNAME` (consulta qué usuario pide para tokens).

6. Comprueba el estado:

   ```sh
   mise run flux-status -- <kube-context>
   ```

Tras el bootstrap, Flux gestiona su propia configuración y Flux Operator desde Git. Los cambios se hacen por PR, no volviendo a ejecutar la tarea.

## Promoción entre entornos

1. CI publica una versión nueva del chart.
2. `dev` usa un rango (`ref.semver` en `apps/dev/kustomization.yaml`) y la despliega solo.
3. Valida la versión en `dev`.
4. Abre un PR que cambie `ref.tag` en `apps/preprod/kustomization.yaml`. Al fusionarlo, Flux la despliega.
5. Repite el paso con `apps/prod/kustomization.yaml`.

Para volver atrás, revierte el commit. No reutilices versiones ya publicadas ni uses `latest`: lo que llega a `prod` debe ser exactamente lo validado.

## Secretos

Cada entorno tiene sus propios destinatarios en `.sops.yaml`:

| Ruta | Pueden descifrar |
|---|---|
| `{apps,infrastructure,clusters}/dev/` | Cluster de dev y equipo |
| `{apps,infrastructure,clusters}/preprod/` | Cluster de preprod y equipo |
| `{apps,infrastructure,clusters}/prod/` | Cluster de prod y administradores de prod |
| `local/` | Equipo |

- En las carpetas de entorno, los `*.secret(s).yaml` deben ser manifiestos `kind: Secret` y añadirse al `kustomization.yaml` si la carpeta lo tiene. Solo se cifran `data` y `stringData`, porque Flux necesita el resto en claro. Un hook de pre-commit rechaza cualquier otro tipo de archivo, que quedaría sin cifrar.
- Los values de un `HelmRelease` se pasan con `valuesFrom` desde un `Secret`.
- Un secreto fuera de estas rutas, como `apps/base/`, no se puede cifrar: no tiene regla.
- `mise run decrypt` omite los archivos sin clave disponible y lo indica al final.

## Proteger prod

La plantilla funciona con cualquier servidor Git accesible por HTTPS o SSH. El repositorio incluye `CODEOWNERS`, pero el resto se configura en tu proveedor y en el cluster. Si tu proveedor no admite `CODEOWNERS`, o lo limita a ciertos planes, define los revisores por ruta en sus reglas de rama:

- **Rama `main`:** PR obligatorio con revisión de CODEOWNERS, checks obligatorios y sin force push, sin excepciones para administradores salvo emergencias.
- **Personas:** solo lectura por RBAC en el cluster de `prod`. Los cambios van por Git.
- **Credenciales:** token de Flux de solo lectura y CI sin acceso al cluster de `prod`.
- **Datos:** añade `kustomize.toolkit.fluxcd.io/prune: disabled` a los recursos que no deban borrarse al quitarlos de Git, como PVC.

`CODEOWNERS` no limita quién lee el repositorio. Si la configuración de `prod` no debe ser visible para todo el equipo, usa un repositorio aparte.

## Comandos para el Desarrollo

| Comando | Descripción |
|---|---|
| `mise run init` | Configura el entorno completo (pre-commit, clave age, plugins de helm) — ver "Primeros pasos" |
| `mise run age-keygen` | Solo la parte de la clave age: genera/reutiliza `~/.config/sops/age/keys.txt` y la pone como clave del equipo en `.sops.yaml` |
| `mise run add-recipient -- <dev\|preprod\|prod\|local> <age1...>` | Agrega una public key age a la regla indicada de `.sops.yaml` y sincroniza sus secrets con `sops updatekeys` (uso: un compañero nuevo en el equipo) |
| `mise run encrypt` | Encripta todos los archivos `*.secret(s).yaml` / `*.secret(s).yml` con sops |
| `mise run decrypt [-- <ruta>]` | Desencripta los archivos `*.secret(s).yaml` / `*.secret(s).yml` para los que tienes clave |
| `mise run edit -- <archivo>` | Abre un secret encriptado para editarlo con sops (re-encripta al guardar) |
| `mise run configure` | Pregunta nombre del proyecto, URL y protocolo del repositorio, rama y aprobadores de prod, y los escribe en la plantilla |
| `mise run validate` | Valida los manifiestos de todos los entornos con `kustomize` y `kubeconform` (requiere red para descargar esquemas) |
| `mise run flux-keygen -- <env>` | Genera la clave age de un cluster y la agrega a `.sops.yaml` |
| `mise run flux-bootstrap -- <env> <kube-context>` | Instala Flux Operator y Flux en un cluster. Requiere `GIT_TOKEN` y opcionalmente `GIT_USERNAME` (https), o `GIT_SSH_KEY_FILE` (ssh) |
| `mise run flux-status -- <kube-context>` | Muestra el estado de Flux en un cluster |
| `mise run flux-diff -- <env> <kube-context>` | Compara los manifiestos locales de un entorno con su cluster |

## Herramientas

- **kubectl** / **helm**: gestión del cluster y los charts.
- **flux** / **flux-operator**: CLI de Flux y de Flux Operator, que instala y actualiza Flux en cada cluster. Flux Operator se distribuye bajo AGPL-3.0: revísalo si vas a redistribuirlo o modificarlo.
- **kustomize** / **kubeconform**: construcción de los overlays y validación de los manifiestos.
- **helm diff** / **helm secrets**: plugins para trabajar con helm a mano. Flux no los necesita: `helm secrets` sirve para los values de `local/`, y en los clusters con Flux, usa `mise run flux-diff`.
- **sops** + **age**: encriptado de secretos, ver "Secretos".
- **pre-commit**: hooks de trailing whitespace, fin de archivo, yaml válido, gitleaks, verificación de que los `*.secret(s).yaml` estén encriptados y de que los de cada entorno sean `kind: Secret`.

Extensión de VSCode recomendada: `signageos.signageos-vscode-sops` (ya configurada en `.vscode/`) para editar los secrets encriptados directamente en el editor.
