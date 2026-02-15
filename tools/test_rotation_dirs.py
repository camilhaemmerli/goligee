"""Diagnostic: feed a known SE-pointing arrow into PixelLab rotate_8_directions
and save the results to determine the actual direction mapping.

Usage:
    python tools/test_rotation_dirs.py
"""
from __future__ import annotations

import base64
import io
import math
import os
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow required. Run: pip install Pillow")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = PROJECT_ROOT / "tools"
DEBUG_DIR = PROJECT_ROOT / "assets" / "sprites" / "_debug"
ENV_FILE = PROJECT_ROOT / ".env"

# Reuse PixelLabClient from generate_assets
sys.path.insert(0, str(TOOLS_DIR))
from generate_assets import PixelLabClient, img_to_b64, remove_background


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def load_api_key() -> str:
    key = os.environ.get("PIXELLAB_API_KEY")
    if key:
        return key
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith("PIXELLAB_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("ERROR: PIXELLAB_API_KEY not found. Set it in .env or as environment variable.")
    sys.exit(1)


def draw_se_arrow(size: int = 64) -> bytes:
    """Draw a bright red arrow pointing SE on a magenta (#FF00FF) background.

    The arrow clearly points to the bottom-right corner so its direction
    is unambiguous when visually inspecting rotated results.
    """
    MAGENTA = (255, 0, 255, 255)
    RED = (220, 30, 30, 255)
    DARK_RED = (160, 20, 20, 255)

    img = Image.new("RGBA", (size, size), MAGENTA)
    draw = ImageDraw.Draw(img)

    # Arrow shaft: thick line from top-left area to center-right area
    # pointing SE (toward bottom-right)
    cx, cy = size // 2, size // 2

    # Shaft endpoints
    shaft_start = (cx - 16, cy - 16)  # upper-left
    shaft_end = (cx + 12, cy + 12)    # lower-right (SE direction)

    # Draw thick shaft
    draw.line([shaft_start, shaft_end], fill=RED, width=5)

    # Arrowhead: triangle pointing SE
    # Tip at bottom-right, two base points perpendicular to shaft direction
    tip = (cx + 20, cy + 20)
    # SE direction vector is (1, 1)/sqrt(2); perpendicular is (-1, 1)/sqrt(2)
    perp_len = 10
    base_center = (cx + 8, cy + 8)
    base1 = (base_center[0] - perp_len, base_center[1] + perp_len // 2)
    base2 = (base_center[0] + perp_len // 2, base_center[1] - perp_len)

    draw.polygon([tip, base1, base2], fill=RED, outline=DARK_RED)

    # Add a small "SE" label in the corner for extra clarity
    try:
        font = ImageFont.load_default()
        draw.text((2, 2), "SE", fill=(255, 255, 255, 255), font=font)
    except Exception:
        pass  # Font not available, arrow shape is sufficient

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def build_composite_sheet(images: list[tuple[str, bytes, int]],
                          cell_size: int = 96) -> bytes:
    """Build a labeled 4x2 grid showing all 8 rotation results.

    Each cell shows the arrow image with text overlay: "idx={i} api={label}"
    """
    cols, rows = 4, 2
    margin = 4
    label_h = 18
    total_w = cols * (cell_size + margin) + margin
    total_h = rows * (cell_size + label_h + margin) + margin

    sheet = Image.new("RGBA", (total_w, total_h), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    for idx, (api_label, img_data, i) in enumerate(images):
        col = idx % cols
        row = idx // cols
        x = margin + col * (cell_size + margin)
        y = margin + row * (cell_size + label_h + margin)

        # Draw label above
        label = f"idx={i} api={api_label}"
        draw.text((x + 2, y + 2), label, fill=(255, 255, 100, 255), font=font)

        # Draw the arrow image
        try:
            arrow_img = Image.open(io.BytesIO(img_data)).convert("RGBA")
            arrow_img = arrow_img.resize((cell_size, cell_size), Image.NEAREST)
            # Paste onto sheet (composite to handle transparency)
            sheet.paste(arrow_img, (x, y + label_h), arrow_img)
        except Exception as e:
            draw.text((x + 4, y + label_h + 20), f"ERR: {e}", fill=(255, 0, 0, 255))

    buf = io.BytesIO()
    sheet.save(buf, format="PNG")
    return buf.getvalue()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    DEBUG_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Draw the SE arrow reference
    print("Drawing SE reference arrow...")
    arrow_bytes = draw_se_arrow(64)
    ref_path = DEBUG_DIR / "arrow_reference_SE.png"
    ref_path.write_bytes(arrow_bytes)
    print(f"  Saved reference: {ref_path}")

    # 2. Initialize PixelLab client
    api_key = load_api_key()
    client = PixelLabClient(api_key)
    print("PixelLab client initialized.")

    # 3. Call rotate_8_directions
    print("Calling rotate_8_directions (this may take 2-5 minutes)...")
    arrow_b64 = img_to_b64(arrow_bytes)
    rotations = client.rotate_8_directions(
        arrow_b64, 64, 64,
        view="low top-down",
        method="rotate_character",
    )
    print(f"  Got {len(rotations)} rotations back.")

    # 4. Save each result individually + collect for sheet
    API_DIR_NAMES = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
    sheet_items = []

    for i, (api_dir, img_data) in enumerate(rotations):
        # Remove background (magenta chroma-key)
        cleaned = remove_background(img_data)

        fname = f"arrow_{i}_{api_dir}.png"
        out_path = DEBUG_DIR / fname
        out_path.write_bytes(cleaned)
        print(f"  [{i}] api_label='{api_dir}' -> {fname}")

        sheet_items.append((api_dir, cleaned, i))

    # 5. Build composite sheet
    print("Building composite sheet...")
    sheet_bytes = build_composite_sheet(sheet_items)
    sheet_path = DEBUG_DIR / "rotation_map_sheet.png"
    sheet_path.write_bytes(sheet_bytes)
    print(f"  Saved sheet: {sheet_path}")

    # Also save the raw (non-bg-removed) versions for comparison
    for i, (api_dir, img_data) in enumerate(rotations):
        raw_path = DEBUG_DIR / f"arrow_{i}_{api_dir}_raw.png"
        raw_path.write_bytes(img_data)

    # 6. Open in Preview
    print("Opening in Preview...")
    subprocess.run(["open", "-a", "Preview", str(sheet_path)])

    print("\n=== ANALYSIS ===")
    print("Compare each arrow's pointing direction against its API label.")
    print("The reference arrow points SE. After rotation:")
    print("  - If idx=0 (api='s') shows arrow pointing S, the label is correct")
    print("  - If idx=1 (api='sw') shows arrow pointing SE, then idx 1 is actually SE")
    print("  - etc.")
    print(f"\nCurrent CORRECTED_DIRS: {['s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw']}")
    print("Update generate_assets.py:_gen_turret_rotations() with verified mapping.")


if __name__ == "__main__":
    main()
