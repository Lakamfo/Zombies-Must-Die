import bpy
import bmesh
import numpy as np
from mathutils import Vector

TILE_SIZE = 4

COLOR_IMAGE_NAME = "ColorPalette"
ROUGHNESS_IMAGE_NAME = "RoughnessPalette"
METALLIC_IMAGE_NAME = "MetallicPalette"

MATERIAL_NAME = "Palette_Material"
UV_NAME = "PaletteUV"


def get_input(node, name):
    socket = node.inputs.get(name)

    if socket and not socket.is_linked:
        return socket.default_value

    return None


def get_material_color(mat):
    if mat is None:
        return (0.8, 0.8, 0.8, 1.0)

    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:

            if node.type == 'BSDF_PRINCIPLED':
                value = get_input(node, "Base Color")

                if value:
                    return tuple(value)

            elif node.type == 'BSDF_DIFFUSE':
                value = get_input(node, "Color")

                if value:
                    return (value[0], value[1], value[2], 1.0)

            elif node.type == 'EMISSION':
                value = get_input(node, "Color")

                if value:
                    return (value[0], value[1], value[2], 1.0)

    return tuple(mat.diffuse_color)


def get_material_roughness(mat):
    if mat is None:
        return 0.5

    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:

            if node.type in {
                'BSDF_PRINCIPLED',
                'BSDF_DIFFUSE',
                'BSDF_GLOSSY'
            }:
                value = get_input(node, "Roughness")

                if value is not None:
                    return float(value)

    return float(getattr(mat, "roughness", 0.5))


def get_material_metallic(mat):
    if mat is None:
        return 0.0

    if mat.use_nodes and mat.node_tree:
        for node in mat.node_tree.nodes:

            if node.type == 'BSDF_PRINCIPLED':
                value = get_input(node, "Metallic")

                if value is not None:
                    return float(value)

    return float(getattr(mat, "metallic", 0.0))


def linear_to_srgb(color):
    color = np.clip(color, 0.0, 1.0)

    low = color * 12.92
    high = 1.055 * np.power(np.maximum(color, 1e-9), 1.0 / 2.4) - 0.055

    return np.where(color <= 0.0031308, low, high)


def create_image(name, width, height):
    old = bpy.data.images.get(name)

    if old:
        bpy.data.images.remove(old)

    return bpy.data.images.new(
        name,
        width=width,
        height=height,
        alpha=True
    )


def build_color_palette(colors):
    width = TILE_SIZE * len(colors)
    height = TILE_SIZE

    image = create_image(COLOR_IMAGE_NAME, width, height)

    pixels = np.zeros((height, width, 4), dtype=np.float32)

    for index, color in enumerate(colors):

        start = index * TILE_SIZE
        end = start + TILE_SIZE

        pixels[:, start:end] = color

    pixels[:, :, :3] = linear_to_srgb(pixels[:, :, :3])

    image.pixels = pixels.reshape(-1).tolist()
    image.pack()

    return image


def build_value_palette(values, image_name):
    width = TILE_SIZE * len(values)
    height = TILE_SIZE

    image = create_image(image_name, width, height)

    pixels = np.zeros((height, width, 4), dtype=np.float32)

    for index, value in enumerate(values):

        start = index * TILE_SIZE
        end = start + TILE_SIZE

        pixels[:, start:end, 0] = value
        pixels[:, start:end, 1] = value
        pixels[:, start:end, 2] = value
        pixels[:, start:end, 3] = 1.0

    image.pixels = pixels.reshape(-1).tolist()
    image.pack()

    return image


def assign_uvs(obj, material_map, tile_count):
    mesh = obj.data

    while mesh.uv_layers:
        mesh.uv_layers.remove(mesh.uv_layers[0])

    mesh.uv_layers.new(name=UV_NAME)
    mesh.uv_layers.active = mesh.uv_layers[UV_NAME]

    bm = bmesh.new()
    bm.from_mesh(mesh)

    uv_layer = bm.loops.layers.uv[UV_NAME]

    for face in bm.faces:

        tile = material_map.get(face.material_index, 0)

        uv = Vector((
            (tile + 0.5) / tile_count,
            0.5
        ))

        for loop in face.loops:
            loop[uv_layer].uv = uv

    bm.to_mesh(mesh)
    bm.free()

    mesh.update()


def add_texture_node(nodes, links, image, uv_output, location, colorspace):
    tex = nodes.new("ShaderNodeTexImage")

    tex.location = location
    tex.image = image
    tex.interpolation = 'Closest'

    image.colorspace_settings.name = colorspace

    links.new(uv_output, tex.inputs["Vector"])

    return tex


def create_material(color_img, roughness_img, metallic_img):
    old = bpy.data.materials.get(MATERIAL_NAME)

    if old:
        bpy.data.materials.remove(old)

    material = bpy.data.materials.new(MATERIAL_NAME)
    material.use_nodes = True

    nodes = material.node_tree.nodes
    links = material.node_tree.links

    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (800, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (350, 0)

    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    uv = nodes.new("ShaderNodeUVMap")
    uv.location = (-700, 0)
    uv.uv_map = UV_NAME

    color_tex = add_texture_node(
        nodes,
        links,
        color_img,
        uv.outputs["UV"],
        (-250, 250),
        'sRGB'
    )

    roughness_tex = add_texture_node(
        nodes,
        links,
        roughness_img,
        uv.outputs["UV"],
        (-250, 0),
        'Non-Color'
    )

    metallic_tex = add_texture_node(
        nodes,
        links,
        metallic_img,
        uv.outputs["UV"],
        (-250, -250),
        'Non-Color'
    )

    links.new(color_tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(color_tex.outputs["Alpha"], bsdf.inputs["Alpha"])

    links.new(roughness_tex.outputs["Color"], bsdf.inputs["Roughness"])
    links.new(metallic_tex.outputs["Color"], bsdf.inputs["Metallic"])

    return material


def main():
    obj = bpy.context.active_object

    if obj is None or obj.type != 'MESH':
        raise RuntimeError("Выбери mesh объект")

    if not obj.material_slots:
        raise RuntimeError("У объекта нет материалов")

    palette_lookup = {}

    colors = []
    roughness = []
    metallic = []

    material_map = {}

    for slot_index, slot in enumerate(obj.material_slots):

        material = slot.material

        color = get_material_color(material)
        rough = get_material_roughness(material)
        metal = get_material_metallic(material)

        key = (
            tuple(round(v, 4) for v in color),
            round(rough, 4),
            round(metal, 4)
        )

        if key not in palette_lookup:

            palette_lookup[key] = len(colors)

            colors.append(color)
            roughness.append(rough)
            metallic.append(metal)

        material_map[slot_index] = palette_lookup[key]

    color_img = build_color_palette(colors)

    roughness_img = build_value_palette(
        roughness,
        ROUGHNESS_IMAGE_NAME
    )

    metallic_img = build_value_palette(
        metallic,
        METALLIC_IMAGE_NAME
    )

    assign_uvs(
        obj,
        material_map,
        len(colors)
    )

    material = create_material(
        color_img,
        roughness_img,
        metallic_img
    )

    obj.data.materials.clear()
    obj.data.materials.append(material)

    for poly in obj.data.polygons:
        poly.material_index = 0

    print("Palette generated")


if __name__ == "__main__":
    main()
