# Install the app

## Android

Install from **F-Droid**, which builds and signs the app from source: [LibreNotes on F-Droid](https://f-droid.org/packages/dev.librenotes.app/).

You can also download the APK from the [GitHub releases page](https://github.com/Piliii/LibreNotes/releases/latest).

> F-Droid and the GitHub APK are signed with different keys, so Android won't update one into the other. To switch, uninstall and reinstall from the source you want. Export your notes first if they aren't synced.

## Linux

- **Arch Linux:** install `librenotes-bin` from the AUR.
- **Debian, Ubuntu, Mint and derivatives:** install the `.deb` package.
- **Fedora, openSUSE and derivatives:** install the `.rpm` package.
- **Any distribution:** download the AppImage or tarball from the [releases page](https://github.com/Piliii/LibreNotes/releases/latest).

> The `.deb` and `.rpm` packages arrive with v1.6.0. Until then, use the AppImage or tarball.

### Debian, Ubuntu and derivatives

Download `LibreNotes-<version>-amd64.deb` (or `arm64`) from the releases page, then:

```bash
sudo apt install ./LibreNotes-<version>-amd64.deb
```

`apt` pulls in the dependencies (GTK 3, libsecret and keybinder) for you.

### Fedora, openSUSE and derivatives

Download `LibreNotes-<version>-x86_64.rpm` (or `aarch64`), then:

```bash
sudo dnf install ./LibreNotes-<version>-x86_64.rpm     # Fedora
sudo zypper install ./LibreNotes-<version>-x86_64.rpm  # openSUSE
```

The package has been tested on Fedora. openSUSE and arm64 builds haven't been tested yet.

Both packages install the app to `/opt/librenotes`, add a `librenotes` command and an application menu entry, and uninstall cleanly with your package manager.

Quick capture (Ctrl+Alt+N) needs the `keybinder-3.0` library and currently works on X11 sessions only.

## Windows

Windows support is planned. Follow the [releases page](https://github.com/Piliii/LibreNotes/releases) for news.

## Moving existing notes in

Open the import/export page from the app's menu. You can import `.md`, `.markdown` and `.txt` files, and export every note as plain Markdown files.
