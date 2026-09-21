#!/usr/bin/env python3
"""
Slices a ripped tile sheet into a clean, de-duplicated Sparrow atlas (PNG + XML)
that the Overworld Editor can use as a tile palette.

What it does:
  - keys out the sheet background colour (transparent)
  - walks the tile grid (tile size + 1px separators, as ripped sheets usually are)
  - drops empty tiles and removes duplicates
  - repacks what is left into a compact sheet with no gaps
  - writes a Sparrow atlas where every tile is one frame named tileNNNN

Usage:
  python slice_tileset.py <input.png> <output_basename> [options]

Options:
  --tile N           tile size in pixels (default 8)
  --block N          glue NxN source tiles into one output tile, dropping the
                     separators in between (default 1). --tile 8 --block 2
                     turns an 8px grid into clean 16x16 blocks.
  --spacing N        pixels between tiles in the source sheet (default 1)
  --margin N         pixels before the first tile (default 0)
  --bg RRGGBB        background colour (default: the most common colour)
  --keep-bg          do NOT make the background transparent
  --crop x,y,w,h     only read this part of the sheet
  --exclude x,y,w,h  skip tiles overlapping this rect (repeatable, e.g. credits)
  --columns N        columns in the packed sheet (default 32)
  --ground           keep one fully-background tile as an opaque "ground" tile
  --out DIR          output directory (default: next to the input)

Example:
  python slice_tileset.py "art/overworld_source/overworld.png" overworld_tiles ^
      --tile 8 --out assets/shared/images/overworld/og_mario
"""

import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow. Instalalo con:  python -m pip install pillow")


def parse_rect(text):
    parts = [int(p) for p in text.split(",")]
    if len(parts) != 4:
        raise ValueError("el rectangulo debe ser x,y,w,h")
    return tuple(parts)


def parse_args(argv):
    opts = {
        "tile": 8, "block": 1, "spacing": 1, "margin": 0, "bg": None, "keep_bg": False,
        "crop": None, "exclude": [], "columns": 32, "ground": False, "out": None,
    }
    positional = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--keep-bg":
            opts["keep_bg"] = True
        elif arg == "--ground":
            opts["ground"] = True
        elif arg.startswith("--"):
            name = arg[2:].replace("-", "_")
            i += 1
            value = argv[i]
            if name in ("tile", "block", "spacing", "margin", "columns"):
                opts[name] = int(value)
            elif name == "crop":
                opts["crop"] = parse_rect(value)
            elif name == "exclude":
                opts["exclude"].append(parse_rect(value))
            elif name == "bg":
                value = value.lstrip("#")
                opts["bg"] = (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)
            elif name == "out":
                opts["out"] = value
            else:
                raise ValueError("opcion desconocida: " + arg)
        else:
            positional.append(arg)
        i += 1

    if len(positional) != 2:
        sys.exit(__doc__)
    return positional[0], positional[1], opts


def overlaps(x, y, size, rects):
    for rx, ry, rw, rh in rects:
        if x < rx + rw and x + size > rx and y < ry + rh and y + size > ry:
            return True
    return False


def main():
    src_path, out_name, opts = parse_args(sys.argv[1:])

    image = Image.open(src_path).convert("RGBA")
    if opts["crop"]:
        cx, cy, cw, ch = opts["crop"]
        image = image.crop((cx, cy, cx + cw, cy + ch))

    background = opts["bg"] or Counter(image.getdata()).most_common(1)[0][0]
    source_tile = opts["tile"]
    block = max(1, opts["block"])
    tile = source_tile * block
    pitch = source_tile + opts["spacing"]
    step = pitch * block
    span = pitch * block - opts["spacing"]  # ancho real que ocupa un bloque en la hoja
    width, height = image.size

    unique = []          # lista de bytes de cada tile distinto
    seen = {}            # bytes -> indice
    ground_added = False
    skipped_empty = 0

    def read_block(bx, by):
        """Pega las NxN celdas del bloque quitando los separadores."""
        if block == 1:
            return image.crop((bx, by, bx + source_tile, by + source_tile))

        glued = Image.new("RGBA", (tile, tile), background)
        for row in range(block):
            for col in range(block):
                sx = bx + col * pitch
                sy = by + row * pitch
                glued.paste(image.crop((sx, sy, sx + source_tile, sy + source_tile)),
                            (col * source_tile, row * source_tile))
        return glued

    y = opts["margin"]
    while y + span <= height:
        x = opts["margin"]
        while x + span <= width:
            if overlaps(x, y, span, opts["exclude"]):
                x += step
                continue

            cell = read_block(x, y)
            pixels = list(cell.getdata())
            is_empty = all(p == background for p in pixels)

            if is_empty:
                skipped_empty += 1
                if not (opts["ground"] and not ground_added):
                    x += step
                    continue
                ground_added = True
            elif not opts["keep_bg"]:
                cell.putdata([(0, 0, 0, 0) if p == background else p for p in pixels])

            key = cell.tobytes()
            if key not in seen:
                seen[key] = len(unique)
                unique.append(cell)
            x += step
        y += step

    if not unique:
        sys.exit("No se ha encontrado ningun tile. Revisa --tile / --spacing / --bg.")

    columns = max(1, opts["columns"])
    rows = (len(unique) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * tile, rows * tile), (0, 0, 0, 0))

    lines = ["<?xml version='1.0' encoding='utf-8'?>",
             '<TextureAtlas imagePath="%s.png">' % out_name]

    for index, cell in enumerate(unique):
        px = (index % columns) * tile
        py = (index // columns) * tile
        sheet.paste(cell, (px, py))
        lines.append(
            '\t<SubTexture name="tile%04d" x="%d" y="%d" width="%d" height="%d" '
            'frameX="0" frameY="0" frameWidth="%d" frameHeight="%d"/>'
            % (index, px, py, tile, tile, tile, tile))

    lines.append("</TextureAtlas>")

    out_dir = opts["out"] or os.path.dirname(os.path.abspath(src_path))
    os.makedirs(out_dir, exist_ok=True)
    png_path = os.path.join(out_dir, out_name + ".png")
    xml_path = os.path.join(out_dir, out_name + ".xml")

    sheet.save(png_path)
    with open(xml_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")

    print("Fondo detectado: rgb%s" % (background[:3],))
    print("Tiles unicos:    %d  (%d vacios descartados)" % (len(unique), skipped_empty))
    print("Hoja generada:   %s  (%dx%d)" % (png_path, sheet.size[0], sheet.size[1]))
    print("Atlas generado:  %s" % xml_path)


if __name__ == "__main__":
    main()
