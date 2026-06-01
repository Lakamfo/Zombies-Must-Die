# Blender Material Palette Generator

A small Blender tool that collects color, roughness, and metallic values from a mesh's materials and generates palette textures. Useful for quickly creating a simplified material based on a set of source materials.

## How to use

1. Open the **Scripting** workspace in Blender.
2. Open `script.py` from the `tools/blender-mats_to_pallete` folder.
3. Select the mesh object you want to process.
4. Press the run button.

After that:

* a single material named `Palette_Material` is created for the selected object;
* all faces get UV coordinates pointing to palette tiles;
* three palette images are created: `ColorPalette`, `RoughnessPalette`, and `MetallicPalette`.

## Requirements

* Blender with Python API support
* The object must have at least one material

## Note

The script automatically removes an existing `Palette_Material` if it already exists in the current Blender project file.
