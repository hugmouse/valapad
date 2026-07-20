![Screenshot of ValaPad](https://github.com/hugmouse/valanote/blob/master/data/screenshots/main.webp?raw=true)

# ValaPad

Edit plain-text files with a familiar set of tools.

Written in Vala and uses GTK4. Tested on elementary OS.

## Features

- You can edit files.

## Languages

ValaPad uses English as its source and fallback language. And also translated
to Russian and German.

To update them do:

```sh
ninja -C build com.github.hugmouse.valapad-pot com.github.hugmouse.valapad-update-po
ninja -C build com.github.hugmouse.valapad-extra-pot com.github.hugmouse.valapad-extra-update-po
```

## Building

Requires `vala`, `meson`, `ninja`, `gettext`, `gtk4` (4.12), `granite-7`, `pango`, and `pangocairo`.

```sh
meson setup build
ninja -C build
./build/src/com.github.hugmouse.valapad
```

To install system-wide:

```sh
sudo ninja -C build install
```

## Flatpak

Install the elementary SDK and build the AppCenter package locally:

```sh
flatpak-builder flatpak-build com.github.hugmouse.valapad.yml \
  --user --install --force-clean
flatpak run com.github.hugmouse.valapad
```

GitHub Actions builds a downloadable Flatpak and publishes version tags to [GitHub Releases](https://github.com/hugmouse/valanote/releases).

## License

GPL-3.0-or-later. See [`LICENSE`](LICENSE).
