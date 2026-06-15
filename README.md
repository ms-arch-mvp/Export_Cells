<h1 align="center">Export Cells</h1>

<p align="center">
  <a href="https://github.com/ms-arch-mvp/Export_Cells/releases">Download</a> ·
  <a href="https://ms-arch.gitbook.io/morrowind-visualisation-project/export-cells/functions">Documentation</a> ·
  <a href="https://github.com/ms-arch-mvp/io_scene_mw_mvp">io_scene_mw_mvp</a> ·
  <a href="https://youtu.be/KWqIz32oWKQ">Video</a>
</p>

Export Cells is an MWSE mod that exports cells for visualisation, editing and testing. It is the foundation of the [Morrowind Visualisation Project](https://ms-arch.gitbook.io/morrowind-visualisation-project/) and includes a suite of functions to enable versatile exports.

Export Cells is based on [Export Sphere](https://morrowind-modding.github.io/modding-tools/3d-modeling-tools/export-sphere) and works in conjunction.

<img width="3836" height="2159" alt="Screenshot" src="https://github.com/user-attachments/assets/1d34f998-8ab7-4ccd-96a7-8e93661f97dc" />

### Requirements
* [MGE XE UF](https://www.nexusmods.com/morrowind/mods/57200) with use shared memory enabled
* [Morrowind Script Extender (MWSE)](https://www.nexusmods.com/morrowind/mods/45468)
* [Morrowind Code Patch](https://www.nexusmods.com/morrowind/mods/19510)

### Installation
* Get the download from the releases page and install as a mod.
* Overwrite MWSE.dll in the game directory if you want to use character export functions. MWSE.dll has been provided by [Greatness7](https://github.com/Greatness7) and adds the method shape:applySkinDeform()
* Install [io_scene_mw_mvp](https://github.com/ms-arch-mvp/io_scene_mw_mvp) if you want to import exported NIFs into Blender, with ignore_armatures and ignore_animations enabled to prevent issues.
