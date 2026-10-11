# Nombre del Proyecto

Descripción breve del proyecto. Reemplazar por el propósito real del repositorio.

## Requisitos

- [`mise`](https://mise.jdx.dev/) instalado. El resto de herramientas (`pre-commit`, `sops`, `age`, `kubectl`, `helm`) las gestiona mise, no hace falta instalarlas a mano.

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
- Genera una clave age en `~/.config/sops/age/keys.txt` **si no tienes una ya** (si ya tienes una, por ejemplo de otro proyecto, la reutiliza en vez de sobrescribirla) y mete su public key en `.sops.yaml`.
- Instala los plugins de helm `diff` y `secrets` (si no están instalados ya).

Si prefieres usar una clave age propia en vez de que se genere una nueva, pon tu `keys.txt` en `~/.config/sops/age/keys.txt` *antes* de correr `mise run init` — la detecta y la reutiliza.

## Comandos para el Desarrollo

| Comando | Descripción |
|---|---|
| `mise run init` | Configura el entorno completo (pre-commit, clave age, plugins de helm) — ver "Primeros pasos" |
| `mise run age-keygen` | Solo la parte de la clave age: genera/reutiliza `~/.config/sops/age/keys.txt` y actualiza la public key en `.sops.yaml` |
| `mise run add-recipient -- <age1...>` | Agrega una public key age adicional a `.sops.yaml` y sincroniza los secrets ya encriptados con `sops updatekeys` (uso: un compañero nuevo en el equipo) |
| `mise run encrypt` | Encripta todos los archivos `*.secret(s).yaml` / `*.secret(s).yml` con sops |
| `mise run decrypt` | Desencripta todos los archivos `*.secret(s).yaml` / `*.secret(s).yml` |
| `mise run edit -- <archivo>` | Abre un secret encriptado para editarlo con sops (re-encripta al guardar) |

## Herramientas

- **kubectl** / **helm**: gestión del cluster y los charts.
- **helm diff**: preview de los cambios de un `helm upgrade` antes de aplicarlo (`helm diff upgrade ...`).
- **helm secrets**: integra sops con helm para poder usar `*.secret(s).yaml` como values files encriptados directamente (`helm secrets upgrade ...`).
- **sops** + **age**: encriptado de secretos, ver sección anterior.
- **pre-commit**: hooks de trailing whitespace, fin de archivo, yaml válido, gitleaks y verificación de que los `*.secret(s).yaml` estén encriptados antes de commitear.

Extensión de VSCode recomendada: `signageos.signageos-vscode-sops` (ya configurada en `.vscode/`) para editar los secrets encriptados directamente en el editor.
