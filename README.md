# RigPop

<img src="assets/rigpop-icon.png" alt="RigPop logo" width="128" height="128">

English | [简体中文](README_ZH.md)

A Windows desktop editor for pixel-art characters, animation, and desktop pets.
Create a character once, then export it as a Godot character package or a standalone Windows desktop pet.

RigPop is an early-stage demo. The application interface is currently in Simplified Chinese.

## Features

- Create characters from individual body parts or complete sprite frames.
- Start from a three-head-tall OC base with separate limbs and optional clothing and accessories, or choose an illustrated template.
- Import layered PSD artwork with assembly preview, adjustable rig matching, original positions, and source preservation.
- Edit pixels and palettes, import images, and slice regular sprite sheets.
- Animate with position and rotation keyframes, texture changes, and layered tracks.
- Configure keyboard and mouse bindings, with separate game and desktop previews.
- Run a desktop pet from the system tray. Background controls let the foreground app keep its keyboard input, focus mode lets you control the pet, and fixed mode locks its position and lets mouse clicks pass through.
- Assign persistent expressions or poses to keys, set state-specific actions, or lock movement and jumping while seated. One-shot actions finish before accepting new pet commands.
- Save editable projects as portable JSON and PNG files.
- Export editable projects, Godot character packages, and Windows desktop pet bundles.

## Download

Download the **0.1.2 Windows demo**. [RigPop-0.1.2-win64.zip](https://github.com/LittleCxwx/RigPop/releases/download/v0.1.2/RigPop-0.1.2-win64.zip) · [Release notes and checksum](https://github.com/LittleCxwx/RigPop/releases/tag/v0.1.2)

1. Extract the entire archive into a writable folder.
2. Run `RigPop.exe`.
3. Keep `RigPop.pck`, `rigpop_windows.dll`, `platform/`, `hosts/`, `helpers/`, and the license files alongside the application.

The portable application does not require Godot, Python, or developer tools.
The automatically generated **Source code** archives contain the development project.

**Requirements:** Windows 10/11 x64 and a graphics driver supporting OpenGL 3.3.

## Getting Started

Create a character from a template or import your own artwork, edit its parts and animations,
then preview or export it from the workspace.

Projects are saved next to the application in `portable_data/` by default.
Keep each project's JSON and PNG assets together when moving it to another computer.

See the [user guide](docs/user_guide.md) for the editing and export workflows.

## Development

Use **Godot 4.7.2 stable, standard edition**.

1. Clone or download this repository.
2. Import the root `project.godot` in Godot and wait for resource import to finish.
3. Press **F5** to run the application.

Windows builds also require PowerShell 7 and Python 3 for the template downloader.
See [Build and Release](docs/build_and_release.md) for build commands and packaging.

## Documentation

The detailed guides are currently available in Simplified Chinese.

| Document | Contents |
| --- | --- |
| [User Guide](docs/user_guide.md) | Character editing, animation, previews, and exports |
| [Project Format](docs/format.md) | Project data and export contracts |
| [Build and Release](docs/build_and_release.md) | Windows builds, application icons, and distribution |
| [Development Guide](docs/development.md) | Architecture, module boundaries, and verification |

## Contributing

Use [GitHub Issues](https://github.com/LittleCxwx/RigPop/issues) to report bugs or discuss changes.
Read [Agent.md](Agent.md) and the [development guide](docs/development.md) before contributing code.

## License

RigPop's original source code and documentation are licensed under the [MIT License](LICENSE).
Third-party components and separately identified assets retain their own licenses;
see [Third-Party Notices](THIRD_PARTY_NOTICES.md).

Artwork and characters created or imported by users retain their respective owners' rights.
