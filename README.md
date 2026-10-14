# common-scripts

A collection of helper scripts for setting up and maintaining a development machine.

> **Platform:** all scripts were created and tested for **Ubuntu Linux 22.04 LTS (Jammy Jellyfish)**.
> They may work on other Ubuntu/Debian releases, but that is not guaranteed.
> Script output and comments are written in Portuguese.

## Scripts

| Script | Purpose |
| --- | --- |
| [`setup-frontend.sh`](setup-frontend.sh) | Front-end development environment |
| [`setup-java.sh`](setup-java.sh) | Java JDKs 11, 17 and 25 |
| [`setup-python.sh`](setup-python.sh) | Latest Python via pyenv, plus tooling |
| [`aumentar-root.sh`](aumentar-root.sh) | Free up / grow space on the root filesystem |
| [`montar-apfs.sh`](montar-apfs.sh) | Mount macOS APFS partitions (read-only) |
| [`fix-som-macbookpro2017.sh`](fix-som-macbookpro2017.sh) | Fix internal speakers on MacBook Pro 2016/2017 |
| [`keyboard-macbook-it/instalar-teclado-it-mac.sh`](keyboard-macbook-it/instalar-teclado-it-mac.sh) | Italian Mac keyboard layout |

---

### `setup-frontend.sh`

Installs a complete front-end toolchain:

- Node.js LTS (with npm) through [nvm](https://github.com/nvm-sh/nvm), set as the default version
- Global npm tools: Angular CLI, `gh-pages` and `serve`
- Pre-caches `create-vite` for React projects (Create React App is deprecated)
- GitHub CLI (`gh`), if not already installed

```bash
bash setup-frontend.sh
```

### `setup-java.sh`

Installs OpenJDK **11, 17 and 25** (LTS) from the Eclipse Temurin (Adoptium) repository, since Ubuntu 22.04 does not ship JDK 25.

- JDK 25 becomes the system default (`update-alternatives`)
- Adds `JAVA_HOME` to `~/.bashrc`
- Adds a `jdk` shell function to switch versions in the current terminal: `jdk 11`, `jdk 17`, `jdk 25`

```bash
bash setup-java.sh
```

### `setup-python.sh`

Installs the latest stable Python 3 via [pyenv](https://github.com/pyenv/pyenv) **without touching the system Python** (Ubuntu depends on its native `python3`).

- Build dependencies, pyenv (configured in `~/.bashrc`), latest Python 3 set as global
- Updated `pip`, `setuptools` and `wheel`
- `pipx` and [`uv`](https://github.com/astral-sh/uv)
- Dev tools via pipx: `ruff`, `black`, `ipython`

```bash
bash setup-python.sh
```

### `aumentar-root.sh`

Makes sure the root filesystem (`/`) has at least N GB free (default: 3 GB).

1. **Diagnosis** — shows disk usage, block devices, LVM volume groups and the largest directories.
2. **Cleanup** — prunes unused k3s/Docker images, shrinks the systemd journal, cleans the package cache and orphan packages, removes old snap revisions and rotated logs. Stops as soon as the target is reached.
3. **Grow** — if still short, tries to extend the root filesystem (LVM `lvextend`, or `growpart` + `resize2fs`/`xfs_growfs`/`btrfs` when there is free space on the disk).

```bash
sudo bash aumentar-root.sh          # 3 GB target, asks before each step
sudo bash aumentar-root.sh -g 5     # 5 GB target
sudo bash aumentar-root.sh -y       # no prompts (automatic)
sudo bash aumentar-root.sh -d       # diagnosis only, changes nothing
```

### `montar-apfs.sh`

Mounts macOS **APFS** partitions **read-only** using [apfs-fuse](https://github.com/sgan81/apfs-fuse) (compiled and installed automatically if missing). Detects APFS partitions on its own, supports encrypted volumes (prompts for the password) and picking a volume inside the container.

```bash
sudo ./montar-apfs.sh                         # install (if needed), detect and mount at /mnt/apfs
sudo ./montar-apfs.sh /dev/sdb2               # mount a specific partition
sudo ./montar-apfs.sh -v 1 /dev/sdb2          # choose a volume inside the container
sudo ./montar-apfs.sh -m /mnt/mac /dev/sdb2   # custom mount point
sudo ./montar-apfs.sh -u                      # unmount
```

### `fix-som-macbookpro2017.sh`

Fixes the **internal speakers of Intel MacBook Pro 2016/2017** models (Cirrus Logic CS8409 codec), which are silent on stock Ubuntu. It builds and installs the [snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) driver.

Works with the 22.04 HWE kernel 6.8: since `linux-source-6.8.0` is not in the 22.04 repositories, the script downloads that package from Ubuntu 24.04 (same kernel) and only extracts the source code to `/usr/src` — nothing from 24.04 is installed.

```bash
sudo ./fix-som-macbookpro2017.sh
sudo reboot
```

> Run it again after every kernel update.

### `keyboard-macbook-it/instalar-teclado-it-mac.sh`

Creates and activates a custom XKB layout, **"Italian (Mac 2016, perfect)"**, that reproduces the Italian MacBook keyboard (labelled `US 2016-MAC-IT`) exactly as printed on the keys. The stock Ubuntu Italian layouts do not match the Mac key labels.

![Italian MacBook keyboard (US 2016-MAC-IT)](keyboard-macbook-it/instalar-teclado-it-mac.png)

- Installs the symbols file at `/usr/share/X11/xkb/symbols/itmacpro`
- Registers the layout in `evdev.xml`/`base.xml` (backups are kept) so it shows up in *Settings › Keyboard*
- Activates it in GNOME (and via `setxkbmap` on X11)
- **AltGr** is the right **Alt/option** key, used for the third symbol on a key, e.g.:

| Key | Normal | Shift | AltGr | AltGr+Shift |
| --- | --- | --- | --- | --- |
| `<` | `<` | `>` | `\` | `\|` |
| `'` | `'` | `?` | `` ` `` | |
| `ì` | `ì` | `^` | `~` | |
| `E` | `e` | `E` | `€` | |
| `è` | `è` | `é` | `[` | `{` |
| `+` | `+` | `*` | `]` | `}` |
| `ò` | `ò` | `ç` | `@` | |
| `à` | `à` | `°` | `#` | |

```bash
bash keyboard-macbook-it/instalar-teclado-it-mac.sh            # install and activate
bash keyboard-macbook-it/instalar-teclado-it-mac.sh --remover  # uninstall (back to standard Italian)
```

> On Wayland, log out and back in if the layout does not change immediately.
> Run the script again after the `xkb-data` package is updated.
