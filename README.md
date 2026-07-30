![Screenshot of ValaPad](https://github.com/hugmouse/valanote/blob/master/data/screenshots/main.webp?raw=true)

# ValaPad

Edit plain-text files with a familiar set of tools.

Written in Vala and uses GTK4. Tested on elementary OS.

## Features

- You can edit files.

## Installation
### From AppCenter (Recommended)
Click the button to get ValaPad on AppCenter if you're on elementary OS:

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/dev.mysh.valapad)

### From Source Code (Flatpak)
You'll need `flatpak` and `flatpak-builder` commands installed on your system.

Run `flatpak remote-add` to add AppCenter remote for dependencies:

```
flatpak remote-add --user --if-not-exists appcenter https://flatpak.elementary.io/repo.flatpakrepo
```

To build and install, use `flatpak-builder`, then execute with `flatpak run`:

```
flatpak-builder builddir --user --install --force-clean --install-deps-from=appcenter dev.mysh.valapad.yml
flatpak run dev.mysh.valapad
```

### Building from source (without Flatpak)

Requires `vala`, `meson`, `ninja`, `gettext`, `gtk4` (4.12), `granite-7`, `pango`, and `pangocairo`.

```sh
meson setup build
ninja -C build
./build/src/dev.mysh.valapad
```

To install system-wide:

```sh
sudo ninja -C build install
```

## Enabling debug logs

Run the app with the following environment variable:

```bash
G_MESSAGES_DEBUG=all dev.mysh.valapad
```

## Languages

ValaPad uses English as its source and fallback language. And also translated
to Russian and German.

To update them do:

```sh
ninja -C build dev.mysh.valapad-pot dev.mysh.valapad-update-po
ninja -C build dev.mysh.valapad-extra-pot dev.mysh.valapad-extra-update-po
```

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).
