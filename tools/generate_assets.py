#!/usr/bin/env python3
"""
Goligee Asset Generator -- Batch generate pixel art sprites via PixelLab + Retro Diffusion APIs.

Backends:
    --backend auto             # (default) RD for towers, PixelLab for everything else
    --backend pixellab         # Force PixelLab for all phases
    --backend retrodiffusion   # Force Retro Diffusion for tower phases

Pipeline phases:
    python tools/generate_assets.py --phase turrets        # Tower turrets (SE ref + 8-rotation)
    python tools/generate_assets.py --phase bases          # Tower base platforms
    python tools/generate_assets.py --phase evo-turrets    # Tier 5 evo variant turrets
    python tools/generate_assets.py --phase enemy-chars    # Create enemy characters (8-dir)
    python tools/generate_assets.py --phase enemy-anims    # Walk cycle animations
    python tools/generate_assets.py --phase projectiles    # All projectiles
    python tools/generate_assets.py --phase effects        # Impact/status effects
    python tools/generate_assets.py --phase city           # City buildings
    python tools/generate_assets.py --phase animated       # Animated detail sprites
    python tools/generate_assets.py --phase tiles          # Isometric tiles
    python tools/generate_assets.py --phase tilesets       # Wang-style tilesets
    python tools/generate_assets.py --phase ui             # UI icons
    python tools/generate_assets.py --phase props          # Environment props
    python tools/generate_assets.py --phase bosses         # Boss enemies
    python tools/generate_assets.py --phase all            # Everything

Tower-specific:
    python tools/generate_assets.py --phase bases --towers rubber_bullet,tear_gas
    python tools/generate_assets.py --phase bases --backend retrodiffusion --towers rubber_bullet

Evo turrets:
    python tools/generate_assets.py --phase evo-turrets --variants rubber_bullet_a5
    python tools/generate_assets.py --phase evo-turrets --towers rubber_bullet
    python tools/generate_assets.py --phase evo-turrets

Foundation test (1 tower + 1 enemy):
    python tools/generate_assets.py --test-foundation

Requires: pip install Pillow requests
Env:      PIXELLAB_API_KEY in .env or environment (always required)
          RD_API_KEY in .env or environment (required for --backend retrodiffusion,
          optional for --backend auto — falls back to PixelLab if missing)
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow required. Run: pip install Pillow")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("ERROR: requests required. Run: pip install requests")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = PROJECT_ROOT / "assets" / "sprites"
ENV_FILE = PROJECT_ROOT / ".env"
CHARACTER_MANIFEST = PROJECT_ROOT / "tools" / ".character_manifest.json"

API_BASE = "https://api.pixellab.ai/v2"

PALETTE_CACHE = PROJECT_ROOT / "tools" / ".palette_swatch.png"

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

PALETTE_COLORS = [
    "#0E0E12", "#161618", "#1A1A1E", "#1E1E22", "#28282C", "#2E2E32",
    "#3A3A3E", "#484850", "#585860", "#606068", "#808898",
    "#C8A040", "#D8A040", "#E8A040", "#D06030", "#D04040", "#903020",
    "#5080A0", "#3868A0",
    "#D06040", "#A84030", "#802818", "#E89060",
    "#F0E0C0", "#70A040", "#50A0D0", "#6090B0",
    "#A0D8A0", "#88C888", "#9A9AA0",
]


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def create_palette_swatch() -> str:
    """Create a small image containing all palette colors, return as base64."""
    if PALETTE_CACHE.exists():
        with open(PALETTE_CACHE, "rb") as f:
            return base64.b64encode(f.read()).decode()
    cols = len(PALETTE_COLORS)
    img = Image.new("RGB", (cols, 1))
    for i, c in enumerate(PALETTE_COLORS):
        img.putpixel((i, 0), hex_to_rgb(c))
    img = img.resize((cols * 4, 4), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    PALETTE_CACHE.parent.mkdir(parents=True, exist_ok=True)
    with open(PALETTE_CACHE, "wb") as f:
        f.write(buf.getvalue())
    return base64.b64encode(buf.getvalue()).decode()


# ---------------------------------------------------------------------------
# Character Manifest
# ---------------------------------------------------------------------------

def load_manifest() -> dict:
    if CHARACTER_MANIFEST.exists():
        return json.loads(CHARACTER_MANIFEST.read_text())
    return {}


def save_manifest(manifest: dict) -> None:
    CHARACTER_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    CHARACTER_MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")


# ---------------------------------------------------------------------------
# API Client
# ---------------------------------------------------------------------------

class PixelLabClient:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        })
        self.palette_b64 = create_palette_swatch()

    def _post(self, endpoint: str, payload: dict, timeout: int = 480) -> dict:
        url = f"{API_BASE}/{endpoint}"
        resp = self.session.post(url, json=payload, timeout=timeout)
        if resp.status_code == 429:
            print("  Rate limited, waiting 30s...")
            time.sleep(30)
            resp = self.session.post(url, json=payload, timeout=timeout)
        if not resp.ok:
            print(f"  API error {resp.status_code}: {resp.text[:500]}")
            resp.raise_for_status()
        return resp.json()

    def _get(self, endpoint: str) -> dict:
        url = f"{API_BASE}/{endpoint}"
        resp = self.session.get(url, timeout=60)
        resp.raise_for_status()
        return resp.json()

    def wait_for_job(self, job_id: str, poll_interval: float = 5.0,
                     max_wait: float = 600.0) -> dict:
        """Poll a background job until completion."""
        elapsed = 0.0
        while elapsed < max_wait:
            result = self._get(f"background-jobs/{job_id}")
            status = result.get("status", "")
            if status == "completed":
                return result
            if status == "failed":
                raise RuntimeError(f"Job {job_id} failed: {result}")
            time.sleep(poll_interval)
            elapsed += poll_interval
            print(f"  Waiting for job {job_id}... ({elapsed:.0f}s)")
        raise TimeoutError(f"Job {job_id} did not complete in {max_wait}s")

    # -- Core generation endpoints --

    def generate_image(self, description: str, width: int, height: int,
                       *, isometric: bool = False,
                       transparent_background: bool = False,
                       negative_description: str | None = None,
                       seed: int | None = None,
                       init_image_b64: str | None = None,
                       init_image_strength: float | None = None) -> bytes:
        """Generate a single image via pixflux. Min 32x32."""
        api_w = max(width, 32)
        api_h = max(height, 32)
        payload = {
            "description": description,
            "image_size": {"width": api_w, "height": api_h},
            "isometric": isometric,
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if transparent_background:
            payload["no_background"] = True
        if negative_description:
            payload["negative_description"] = negative_description
        if seed is not None:
            payload["seed"] = seed
        if init_image_b64:
            payload["init_image"] = {"base64": init_image_b64}
            if init_image_strength is not None:
                payload["init_image_strength"] = init_image_strength
        result = self._post("create-image-pixflux", payload)
        return self._extract_image(result)

    def generate_map_object(self, description: str, width: int, height: int,
                            *, view: str = "high top-down",
                            seed: int | None = None) -> bytes:
        """Generate a map/environment object with transparent background (async)."""
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "view": view,
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("map-objects", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_image(result)

    def generate_isometric_tile(self, description: str, size: int = 32,
                                shape: str = "thin tile",
                                seed: int | None = None) -> bytes:
        """Generate an isometric tile (async)."""
        payload = {
            "description": description,
            "image_size": {"width": size, "height": size},
            "isometric_tile_size": size,
            "isometric_tile_shape": shape,
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-isometric-tile", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_image(result)

    # -- Rotation endpoint --

    def rotate_8_directions(self, reference_image_b64: str, width: int, height: int,
                            *, view: str = "low top-down",
                            method: str = "rotate_character") -> list[tuple[str, bytes]]:
        """Generate 8 rotations from a reference sprite.

        Endpoint: /generate-8-rotations-v2
        Size limits: 32-84px
        Returns: list of (direction_name, image_bytes) in order:
            south, south-west, west, north-west, north, north-east, east, south-east
        """
        payload = {
            "reference_image": {
                "image": {"base64": reference_image_b64},
                "width": width,
                "height": height,
            },
            "image_size": {"width": width, "height": height},
            "view": view,
            "method": method,
        }
        result = self._post("generate-8-rotations-v2", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_rotation_images(result)

    # -- Character endpoints --

    def create_character_8dir(self, description: str, width: int, height: int,
                              *, isometric: bool = True,
                              seed: int | None = None) -> tuple[str, list[tuple[str, bytes]]]:
        """Create a persistent character with 8 directional views.

        Endpoint: /create-character-with-8-directions
        Size: 32-400px
        Returns: (character_id, list of (direction_name, image_bytes))
        """
        payload = {
            "description": description,
            "image_size": {"width": width, "height": height},
            "isometric": isometric,
            "color_image": {"base64": self.palette_b64},
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-character-with-8-directions", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        char_id = self._extract_character_id(result)
        images = self._extract_rotation_images(result)
        return (char_id, images)

    def animate_character(self, character_id: str,
                          template_animation_id: str = "walking-4-frames",
                          directions: list[str] | None = None) -> dict[str, list[bytes]]:
        """Animate a stored character using a template.

        Endpoint: /characters/animations
        Returns: dict of {direction_name: [frame_bytes, ...]}
        """
        payload = {
            "character_id": character_id,
            "template_animation_id": template_animation_id,
        }
        if directions is not None:
            payload["directions"] = directions
        # else: null => all 8 directions
        result = self._post("characters/animations", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_animation_frames(result)

    # -- Animate with text --

    def animate_with_text(self, reference_image_b64: str, description: str,
                          width: int, height: int,
                          *, num_frames: int = 4,
                          version: int = 2) -> list[bytes]:
        """Animate a static sprite from text description.

        v1: 64x64 only. v2: 32-128px.
        Returns: list of frame bytes.
        """
        endpoint = "animate-with-text" if version == 1 else "animate-with-text-v2"
        payload = {
            "reference_image": {"image": {"base64": reference_image_b64}},
            "description": description,
            "image_size": {"width": width, "height": height},
            "num_frames": num_frames,
        }
        result = self._post(endpoint, payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_frame_list(result)

    # -- Tileset --

    def create_tileset(self, description: str, tile_size: int = 32,
                       *, seed: int | None = None) -> list[bytes]:
        """Generate a Wang-style tileset with automatic connectivity.

        Returns: list of tile image bytes.
        """
        payload = {
            "description": description,
            "tile_size": tile_size,
            "text_guidance_scale": 8.0,
        }
        if seed is not None:
            payload["seed"] = seed
        result = self._post("create-tileset", payload)
        job_id = result.get("background_job_id") or result.get("job_id")
        if job_id:
            result = self.wait_for_job(job_id)
        return self._extract_tileset_images(result)

    # -- Response parsing helpers --

    def _extract_image(self, result: dict) -> bytes:
        """Extract image bytes from API response and convert to PNG."""
        img_data = self._find_image_data(result)
        if not img_data:
            print(f"  WARNING: Could not extract image from response keys: {list(result.keys())}")
            self._save_debug_response(result)
            return b""
        return img_data

    def _find_image_data(self, result: dict) -> bytes:
        """Search for image data in various response shapes."""
        last_resp = result.get("last_response", {})
        if isinstance(last_resp, dict):
            for img_key in ("quantized_image", "image"):
                img_obj = last_resp.get(img_key, {})
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    return self._rgba_to_png(img_obj)

        for key in ("image", "data", "result"):
            val = result.get(key)
            if isinstance(val, dict):
                if val.get("type") == "rgba_bytes" and val.get("base64"):
                    return self._rgba_to_png(val)
                b64 = val.get("base64") or val.get("image_base64")
                if b64:
                    return base64.b64decode(b64)

        images = result.get("images", [])
        if images:
            first = images[0]
            if isinstance(first, dict):
                if first.get("type") == "rgba_bytes" and first.get("base64"):
                    return self._rgba_to_png(first)
                b64 = first.get("base64") or first.get("image_base64")
                if b64:
                    return base64.b64decode(b64)
            elif isinstance(first, str):
                return base64.b64decode(first)

        return b""

    def _extract_rotation_images(self, result: dict) -> list[tuple[str, bytes]]:
        """Extract 8 directional images from a rotation/character response.

        Expected directions order: s, sw, w, nw, n, ne, e, se
        """
        DIR_NAMES = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
        images = []

        last_resp = result.get("last_response", {})
        if isinstance(last_resp, dict):
            # Try rotation_images / images array in last_response
            img_list = last_resp.get("rotation_images") or last_resp.get("images") or []
            for i, img_obj in enumerate(img_list):
                if i >= 8:
                    break
                direction = DIR_NAMES[i] if i < len(DIR_NAMES) else f"dir{i}"
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    images.append((direction, self._rgba_to_png(img_obj)))
                elif isinstance(img_obj, str):
                    images.append((direction, base64.b64decode(img_obj)))
            if images:
                return images

        # Try top-level arrays
        for key in ("rotation_images", "images", "directions"):
            img_list = result.get(key, [])
            if not img_list:
                continue
            for i, img_obj in enumerate(img_list):
                if i >= 8:
                    break
                direction = DIR_NAMES[i] if i < len(DIR_NAMES) else f"dir{i}"
                if isinstance(img_obj, dict):
                    if img_obj.get("base64"):
                        images.append((direction, self._rgba_to_png(img_obj)))
                    elif img_obj.get("image", {}).get("base64"):
                        images.append((direction, self._rgba_to_png(img_obj["image"])))
                elif isinstance(img_obj, str):
                    images.append((direction, base64.b64decode(img_obj)))
            if images:
                return images

        # Fallback: single image
        single = self._find_image_data(result)
        if single:
            images.append(("se", single))

        if not images:
            print("  WARNING: Could not extract rotation images")
            self._save_debug_response(result)

        return images

    def _extract_character_id(self, result: dict) -> str:
        """Extract character_id from response."""
        for key in ("character_id", "id"):
            val = result.get(key)
            if val:
                return str(val)
        last_resp = result.get("last_response", {})
        if isinstance(last_resp, dict):
            for key in ("character_id", "id"):
                val = last_resp.get(key)
                if val:
                    return str(val)
        print("  WARNING: Could not extract character_id")
        self._save_debug_response(result)
        return ""

    def _extract_animation_frames(self, result: dict) -> dict[str, list[bytes]]:
        """Extract animation frames per direction from response.

        Returns: {direction_name: [frame_bytes, ...]}
        """
        DIR_NAMES = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
        frames: dict[str, list[bytes]] = {}

        last_resp = result.get("last_response", {})
        source = last_resp if isinstance(last_resp, dict) else result

        # Try "animations" key: list of direction animation objects
        anims = source.get("animations") or source.get("directions") or []
        if isinstance(anims, list):
            for i, anim_obj in enumerate(anims):
                if not isinstance(anim_obj, dict):
                    continue
                direction = anim_obj.get("direction", DIR_NAMES[i] if i < len(DIR_NAMES) else f"dir{i}")
                # Normalize direction name
                dir_key = direction.lower().replace("-", "").replace("_", "").replace(" ", "")
                dir_map = {
                    "south": "s", "southwest": "sw", "west": "w", "northwest": "nw",
                    "north": "n", "northeast": "ne", "east": "e", "southeast": "se",
                    "s": "s", "sw": "sw", "w": "w", "nw": "nw",
                    "n": "n", "ne": "ne", "e": "e", "se": "se",
                }
                dir_name = dir_map.get(dir_key, dir_key)
                frame_imgs = anim_obj.get("frames") or anim_obj.get("images") or []
                frame_bytes = []
                for frame in frame_imgs:
                    if isinstance(frame, dict) and frame.get("base64"):
                        frame_bytes.append(self._rgba_to_png(frame))
                    elif isinstance(frame, str):
                        frame_bytes.append(base64.b64decode(frame))
                if frame_bytes:
                    frames[dir_name] = frame_bytes

        if frames:
            return frames

        # Fallback: flat "images" array (all frames in sequence, 4 per direction)
        img_list = source.get("images") or []
        if img_list:
            all_frames = []
            for img_obj in img_list:
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    all_frames.append(self._rgba_to_png(img_obj))
                elif isinstance(img_obj, str):
                    all_frames.append(base64.b64decode(img_obj))
            # Assume 4 frames per direction, 8 directions
            frames_per_dir = max(1, len(all_frames) // 8) if len(all_frames) >= 8 else len(all_frames)
            for i, dir_name in enumerate(DIR_NAMES):
                start = i * frames_per_dir
                end = start + frames_per_dir
                if start < len(all_frames):
                    frames[dir_name] = all_frames[start:end]

        if not frames:
            print("  WARNING: Could not extract animation frames")
            self._save_debug_response(result)

        return frames

    def _extract_frame_list(self, result: dict) -> list[bytes]:
        """Extract a flat list of frame images from response."""
        frames = []
        last_resp = result.get("last_response", {})
        source = last_resp if isinstance(last_resp, dict) else result

        for key in ("frames", "images"):
            img_list = source.get(key, [])
            for img_obj in img_list:
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    frames.append(self._rgba_to_png(img_obj))
                elif isinstance(img_obj, str):
                    frames.append(base64.b64decode(img_obj))
            if frames:
                return frames

        single = self._find_image_data(result)
        if single:
            frames.append(single)

        if not frames:
            print("  WARNING: Could not extract frames")
            self._save_debug_response(result)

        return frames

    def _extract_tileset_images(self, result: dict) -> list[bytes]:
        """Extract tileset tile images from response."""
        tiles = []
        last_resp = result.get("last_response", {})
        source = last_resp if isinstance(last_resp, dict) else result

        for key in ("tiles", "images", "tileset"):
            img_list = source.get(key, [])
            for img_obj in img_list:
                if isinstance(img_obj, dict) and img_obj.get("base64"):
                    tiles.append(self._rgba_to_png(img_obj))
                elif isinstance(img_obj, str):
                    tiles.append(base64.b64decode(img_obj))
            if tiles:
                return tiles

        single = self._find_image_data(result)
        if single:
            tiles.append(single)

        if not tiles:
            print("  WARNING: Could not extract tileset images")
            self._save_debug_response(result)

        return tiles

    def _rgba_to_png(self, img_obj: dict) -> bytes:
        """Convert raw RGBA byte data from the API to a PNG file."""
        raw = base64.b64decode(img_obj["base64"])
        w = img_obj.get("width", 32)
        h = img_obj.get("height", 32)
        try:
            img = Image.frombytes("RGBA", (w, h), raw)
        except ValueError:
            return raw
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    def _save_debug_response(self, result: dict) -> None:
        debug_path = PROJECT_ROOT / "tools" / ".last_response.json"
        with open(debug_path, "w") as f:
            json.dump(result, f, indent=2, default=str)
        print(f"  Response saved to {debug_path}")


# ---------------------------------------------------------------------------
# Retro Diffusion API Client
# ---------------------------------------------------------------------------

class RetroDiffusionClient:
    """Client for the Retro Diffusion API (https://api.retrodiffusion.ai/v1).

    Key differences from PixelLab:
    - Synchronous responses (no polling/background jobs)
    - Auth via X-RD-Token header
    - reference_images: list of base64 strings (up to 9 for RD_PRO)
    - No negative prompts — style + prompt phrasing only
    """

    API_BASE = "https://api.retrodiffusion.ai/v1"

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers["X-RD-Token"] = api_key

    def generate(self, prompt: str, width: int, height: int, *,
                 style: str = "rd_pro__isometric",
                 reference_images: list[str] | None = None,
                 remove_bg: bool = True,
                 seed: int | None = None,
                 num_images: int = 1) -> list[bytes]:
        """Generate images via Retro Diffusion.

        Args:
            prompt: Text description of desired image.
            width: Output width in pixels.
            height: Output height in pixels.
            style: RD prompt_style (default: rd_pro__isometric).
            reference_images: List of base64-encoded reference images (up to 9).
            remove_bg: Whether to remove background.
            seed: Optional seed for reproducibility.
            num_images: Number of images to generate (default 1).

        Returns:
            List of PNG image bytes.
        """
        payload = {
            "prompt": prompt,
            "width": width,
            "height": height,
            "num_images": num_images,
            "prompt_style": style,
            "remove_bg": remove_bg,
        }
        if reference_images:
            payload["reference_images"] = reference_images
        if seed is not None:
            payload["seed"] = seed

        url = f"{self.API_BASE}/inferences"
        resp = self.session.post(url, json=payload, timeout=120)
        if resp.status_code == 429:
            print("  RD rate limited, waiting 30s...")
            time.sleep(30)
            resp = self.session.post(url, json=payload, timeout=120)
        if not resp.ok:
            print(f"  RD API error {resp.status_code}: {resp.text[:500]}")
            resp.raise_for_status()

        data = resp.json()
        remaining = data.get("remaining_credits", "?")
        cost = data.get("credit_cost", "?")
        print(f"  RD credits: {cost} used, {remaining} remaining")

        images = []
        for b64_str in data.get("base64_images", []):
            images.append(base64.b64decode(b64_str))
        return images

    def check_credits(self) -> int:
        """Check remaining credits without generating anything."""
        payload = {
            "prompt": "test",
            "width": 64,
            "height": 64,
            "num_images": 1,
            "prompt_style": "rd_pro__isometric",
            "check_cost": True,
        }
        url = f"{self.API_BASE}/inferences"
        resp = self.session.post(url, json=payload, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return data.get("remaining_credits", 0)


# ---------------------------------------------------------------------------
# Background removal
# ---------------------------------------------------------------------------

def remove_background(img_bytes: bytes, tolerance: int = 30) -> bytes:
    """Remove solid background via flood-fill from edges.

    Uses tight tolerance for dark backgrounds to avoid eating dark sprite content.
    """
    from collections import deque

    img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
    pixels = img.load()
    w, h = img.size

    # Skip if corners are already transparent (API produced transparent bg)
    corner_coords = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    transparent_corners = sum(1 for x, y in corner_coords if pixels[x, y][3] < 10)
    if transparent_corners >= 3:
        return img_bytes

    corners = []
    for x, y in corner_coords:
        corners.append(pixels[x, y][:3])
    bg_color = max(set(corners), key=corners.count)

    # Dark backgrounds need tight tolerance to preserve dark sprite content
    bg_brightness = sum(bg_color)
    if bg_brightness < 90:
        tolerance = 10

    def color_dist(c1, c2):
        return sum((a - b) ** 2 for a, b in zip(c1, c2)) ** 0.5

    visited = set()
    to_clear = set()
    queue = deque()

    for x in range(w):
        for y in (0, h - 1):
            if color_dist(pixels[x, y][:3], bg_color) <= tolerance:
                queue.append((x, y))
                visited.add((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if (x, y) not in visited and color_dist(pixels[x, y][:3], bg_color) <= tolerance:
                queue.append((x, y))
                visited.add((x, y))

    while queue:
        cx, cy = queue.popleft()
        to_clear.add((cx, cy))
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in visited:
                visited.add((nx, ny))
                if color_dist(pixels[nx, ny][:3], bg_color) <= tolerance:
                    queue.append((nx, ny))

    for x, y in to_clear:
        pixels[x, y] = (0, 0, 0, 0)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def remove_ground_stain(img_bytes: bytes) -> bytes:
    """Remove reddish ground shadow pixels from character sprites.

    The AI consistently generates a red/brown ground shadow blob at the feet of
    cop figures. These pixels have a distinctive strongly red-shifted color
    (R >> G, R >> B) that doesn't appear in the dark navy cop uniform.
    Simply erase all such pixels.
    """
    img = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
    pixels = img.load()
    w, h = img.size
    count = 0

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 10 and r > 150 and r > g + 60 and r > b + 60:
                pixels[x, y] = (0, 0, 0, 0)
                count += 1

    if count:
        print(f"    Removed {count} ground stain pixels")

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def img_to_b64(img_bytes: bytes) -> str:
    """Convert image bytes to base64 string."""
    return base64.b64encode(img_bytes).decode()


def save_image(data: bytes, rel_path: str, *, open_viewer: bool = True) -> Path:
    """Save image bytes to sprites dir, return full path."""
    import subprocess
    out = SPRITES_DIR / rel_path
    out.parent.mkdir(parents=True, exist_ok=True)
    if data:
        with open(out, "wb") as f:
            f.write(data)
        print(f"  Saved: {out.relative_to(PROJECT_ROOT)}")
        if open_viewer:
            subprocess.Popen(["open", str(out)])
    else:
        print(f"  SKIPPED (no image data): {rel_path}")
    return out


# ---------------------------------------------------------------------------
# Parallel execution helper
# ---------------------------------------------------------------------------

MAX_WORKERS = 10  # PixelLab concurrency limit


def run_parallel(tasks: list[tuple], max_workers: int = MAX_WORKERS) -> list:
    """Run API tasks concurrently using ThreadPoolExecutor.

    Args:
        tasks: list of (label, fn, args, kwargs) tuples.
        max_workers: max concurrent threads (default 10).

    Returns:
        list of results in the same order as tasks.
        Failed tasks return None.
    """
    results = [None] * len(tasks)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {}
        for i, (label, fn, args, kwargs) in enumerate(tasks):
            futures[pool.submit(fn, *args, **kwargs)] = (i, label)
        for future in as_completed(futures):
            idx, label = futures[future]
            try:
                results[idx] = future.result()
            except Exception as e:
                print(f"  FAILED [{label}]: {e}")
    return results


# ---------------------------------------------------------------------------
# Prompt Definitions
# ---------------------------------------------------------------------------

# -- Composable prompt layers --

# Layer 1: Universal style (used by ALL generators)
STYLE = (
    "16-bit isometric pixel art, isometric 3/4 view, "
    "clean pixel grid, no anti-aliasing, detailed shading"
)

# Layer 2: Lighting (used by scene + sprite generators, NOT characters)
LIGHTING = (
    "light source from top-left casting shadows to bottom-right, "
    "left faces brightest, right faces mid-tone, bottom faces darkest"
)

# Layer 3: Theme/atmosphere (used by scene generators ONLY)
THEME = (
    "satirical riot control police state setting, "
    "Soviet brutalist architecture, raw concrete angular geometry, "
    "dark night scene lit by harsh overhead floodlights, "
    "oppressive authoritarian dystopia, post-Soviet urban decay"
)

# Chroma-key background: request a vivid color the flood-fill can cleanly
# remove without eating dark sprite content.  Every prompt that needs a
# transparent result should include CHROMA_BG instead of "transparent background".
CHROMA_BG = "on solid bright magenta #FF00FF background"

# Layer 4: Negative prompt (used by all transparent-bg generators)
NEGATIVE = (
    "background, scene, environment, building, architecture, street, "
    "urban, night sky, ground, floor, landscape"
)

# -- Composed per-category prompts --

# Scene assets (tiles, buildings, tilesets)
SCENE_PROMPT = f"{STYLE}, {LIGHTING}, {THEME}"

# Isolated sprites (turrets, projectiles, effects, animated details)
SPRITE_PROMPT = f"{STYLE}, {LIGHTING}, single isolated game sprite {CHROMA_BG}"

# Characters (enemies, bosses) -- keep SHORT per learned lesson
CHAR_PROMPT = f"{STYLE}, dark muted colors, warm accents"

# UI icons
UI_PROMPT = (
    "pixel art game icon, clean sharp edges, no anti-aliasing, "
    f"dark theme, {CHROMA_BG}"
)


# ---------------------------------------------------------------------------
# Tower Prompt Grid -- Structured slot-based tower definitions
# ---------------------------------------------------------------------------

# Structural fragments (shared across ALL towers, never change per tower)
TOWER_GROUND = (
    "isometric diamond ground platform at base, 1-tile footprint, "
    "reinforced concrete slab, flush with bottom edge of image, "
    "scattered debris and litter on ground, cigarette butts, shell casings, grime"
)

TOWER_BASE_STRUCTURE = (
    f"isometric low-profile equipment housing {CHROMA_BG}, "
    "compact squat structure on ground platform, wider than tall"
)

TOWER_TURRET_STRUCTURE = (
    f"isolated rotating turret weapon head {CHROMA_BG}, "
    "weapon block centered exactly in middle of artboard, "
    "barrel or emitter may extend past center, "
    "small weapon head only, no body, no base, no platform, no ground"
)

TOWER_GRIT = (
    "weathered and battle-worn, dirt stains, rust streaks, chipped paint, "
    "grime buildup in crevices, intricate surface detail, "
    "scratches and scuff marks, heavy wear and tear"
)

# Negative prompts for base vs turret separation
BASE_NEGATIVE = (
    "weapon, turret, gun, barrel, cannon, nozzle, dish, antenna, camera, "
    "mounted equipment on top, character, person, sky, landscape"
)

TURRET_NEGATIVE = (
    "base, platform, ground, floor, body, tower, building, pedestal, "
    "architecture, structure below, character, person, sky, landscape"
)

# Body height / weapon size → proportion text
BODY_HEIGHT_MAP = {"very_short": "lower 12%", "short": "lower 20%", "medium": "lower 28%", "tall": "lower 35%"}
WEAPON_SIZE_MAP = {"small": "small", "medium": "medium-sized", "large": "large prominent"}


def build_base_prompt(tower: dict) -> str:
    """Assemble a deterministic base prompt from tower slot values."""
    height_pct = BODY_HEIGHT_MAP[tower["body_height"]]
    return (
        f"{STYLE}, {LIGHTING}, "
        f"{TOWER_BASE_STRUCTURE}, "
        f"{tower['material']}, "
        f"{TOWER_GRIT}, "
        f"{tower['accent_name']} {tower['accent_hex']} accent highlights, "
        f"{tower['body_desc']}, "
        f"body occupies {height_pct} of canvas, "
        f"{TOWER_GROUND}, {tower.get('ground_desc', 'standard reinforced slab')}, "
        f"empty flat roof for turret mount, no weapon on top"
    )


def build_turret_prompt(tower: dict) -> str:
    """Assemble a deterministic turret prompt from tower slot values."""
    wsize = WEAPON_SIZE_MAP[tower["weapon_size"]]
    return (
        f"{STYLE}, {LIGHTING}, "
        f"{TOWER_TURRET_STRUCTURE}, "
        f"{tower['material']}, "
        f"{TOWER_GRIT}, "
        f"{tower['accent_name']} {tower['accent_hex']} accent highlights, "
        f"{wsize} {tower['weapon_desc']}, "
        f"{tower['weapon_shape']}"
    )


EVO_SIZE_SCALE = {
    "a": "oversized bulky weapon occupying 70% of artboard, large and heavy",
    "b": "very large weapon occupying 80% of artboard, heavy reinforced chunky",
    "c": "massive dominant weapon filling 90% of artboard, enormous imposing hulking",
}


def build_evo_turret_prompt(variant: dict, parent: dict, path_letter: str = "a") -> str:
    """Assemble a turret prompt for a tier 5 evo variant.

    Inherits material/accent/grit from parent tower but uses the variant's
    own weapon_desc/shape/size with evolved flavor.  Progressive size
    increase per path (a < b < c).
    """
    wsize = WEAPON_SIZE_MAP[variant["weapon_size"]]
    size_mod = EVO_SIZE_SCALE.get(path_letter, EVO_SIZE_SCALE["a"])
    return (
        f"{STYLE}, {LIGHTING}, "
        f"{TOWER_TURRET_STRUCTURE}, "
        f"{parent['material']}, "
        f"{TOWER_GRIT}, "
        f"{parent['accent_name']} {parent['accent_hex']} accent highlights, "
        f"advanced evolved upgraded {wsize} {variant['weapon_desc']}, "
        f"{size_mod}, "
        f"{variant['weapon_shape']}"
    )


def build_evo_turret_fire_prompt(variant: dict, parent: dict, path_letter: str = "a") -> str:
    """Assemble a firing-pose turret prompt for a tier 5 evo variant.

    Same as idle prompt but adds the fire_desc visual effects.
    """
    idle = build_evo_turret_prompt(variant, parent, path_letter)
    fire_desc = variant.get("fire_desc", "")
    if fire_desc:
        return f"{idle}, actively firing, {fire_desc}"
    return f"{idle}, actively firing, muzzle flash, projectile launching"


# Per-tower slot data: shared material + accent, base slots, turret slots
TOWERS = {
    "rubber_bullet": {
        "material": "matte dark gunmetal steel plating, bolted panel seams, industrial rivets, heavy gauge sheet metal, brushed metal finish",
        "accent_hex": "#9A9AA0",
        "accent_name": "silver metallic",
        "body_desc": "extremely low flat wide platform, only 8 pixels tall body, trapezoidal wider at bottom, black and yellow diagonal hazard stripes, gunmetal steel flat top",
        "body_height": "very_short",
        "ground_desc": "concrete slab",
        "weapon_desc": "police riot grenade launcher with large round drum cylinder magazine on side, short wide barrel, black and yellow hazard stripe ring base, no handle no grip",
        "weapon_shape": "short wide barrel pointing forward-right, big round drum magazine attached to side, flat circular base with yellow black diagonal stripes",
        "weapon_size": "small",
        "skip_base": True,
        "cop_prompt": (
            f"{STYLE}, {LIGHTING}, "
            "single standing riot police officer character, "
            "full body visible head to boots, facing south-east, "
            "dark navy tactical uniform, body armor vest, combat helmet with visor, "
            "holding rubber bullet launcher in both hands at ready position, "
            "black combat boots, knee pads, utility belt, "
            "intimidating authoritarian stance, "
            "no ground, no shadow, no platform, no floor beneath feet, "
            f"weathered gear, scuff marks, {CHROMA_BG}"
        ),
        "cop_fire_prompt": (
            f"{STYLE}, {LIGHTING}, "
            "single riot police officer character firing weapon, "
            "full body visible head to boots, facing south-east, "
            "dark navy tactical uniform, body armor vest, combat helmet with visor, "
            "aiming and firing rubber bullet launcher, weapon raised to shoulder, recoil stance, "
            "muzzle flash at barrel tip, "
            "black combat boots, knee pads, utility belt, "
            "aggressive firing pose, leaning forward, "
            "no ground, no shadow, no platform, no floor beneath feet, "
            f"weathered gear, scuff marks, {CHROMA_BG}"
        ),
    },
    "tear_gas": {
        "material": "vented steel panels, chemical hazmat housing, corroded metal plating",
        "accent_hex": "#70A040",
        "accent_name": "chemical green",
        "body_desc": "wide chemical barrel cluster, three stubby hazmat canisters strapped together, drip stains",
        "body_height": "short",
        "ground_desc": "chemical-stained reinforced slab",
        "weapon_desc": "multi-tube grenade launcher rack, 6 angled launch tubes, hazmat yellow markings",
        "weapon_shape": "wide rectangular rack with angled tube cluster",
        "weapon_size": "large",
    },
    "taser_grid": {
        "material": "insulated dark metal panels, high voltage warning markings, rubber-sealed joints",
        "accent_hex": "#50A0D0",
        "accent_name": "electric blue",
        "body_desc": "compact transformer box, exposed copper coils on top, rubber insulator feet, warning stickers",
        "body_height": "short",
        "ground_desc": "insulated rubber-topped slab",
        "weapon_desc": "tesla coil twin conductor prongs, high voltage electrode pair, arc gap between tips",
        "weapon_shape": "vertical prong pair rising from compact base block",
        "weapon_size": "medium",
    },
    "water_cannon": {
        "material": "industrial steel plating, pipe fittings, pressure gauge rivets, hydraulic joints",
        "accent_hex": "#6090B0",
        "accent_name": "cool blue",
        "body_desc": "squat cylindrical water tank, pressure gauge on front, hose coils around base, valve wheel",
        "body_height": "short",
        "ground_desc": "drain-grated reinforced slab",
        "weapon_desc": "industrial fire hose nozzle on swivel, chrome nozzle head, pressurized spray tip",
        "weapon_shape": "cylindrical swivel mount with forward-pointing nozzle",
        "weapon_size": "large",
    },
    "surveillance": {
        "material": "dark matte composite panels, data cable conduits, sealed equipment housing",
        "accent_hex": "#A0D8A0",
        "accent_name": "terminal green",
        "body_desc": "low server cabinet rack, blinking status LEDs behind mesh panel, cable bundle exiting side",
        "body_height": "medium",
        "ground_desc": "cable-routed reinforced slab",
        "weapon_desc": "satellite dish with camera cluster, radar spinner, CCTV cameras, red recording light",
        "weapon_shape": "dish and antenna array fanning outward from compact hub",
        "weapon_size": "medium",
    },
    "pepper_spray": {
        "material": "chemical-resistant steel panels, pressurized canister housing, hazmat orange seals",
        "accent_hex": "#D06030",
        "accent_name": "hazmat orange",
        "body_desc": "row of pressurized spray canisters in metal cradle, pressure manifold, drip tray underneath",
        "body_height": "short",
        "ground_desc": "chemical-resistant reinforced slab",
        "weapon_desc": "industrial aerosol nozzle array, spray cone emitter head, pressurized chemical sprayer",
        "weapon_shape": "fan-shaped nozzle array spreading from compact manifold",
        "weapon_size": "medium",
    },
    "lrad": {
        "material": "military-grade dark metal, sound dampening panels, acoustic foam inserts, heavy bolts",
        "accent_hex": "#D8A040",
        "accent_name": "warning amber",
        "body_desc": "compact amplifier stack, speaker cone vents on sides, vibration dampener feet, power cable coil",
        "body_height": "short",
        "ground_desc": "vibration-dampened reinforced slab",
        "weapon_desc": "large warning-amber orange parabolic speaker dish, bright #D8A040 orange concentric ring emitter face, military audio weapon",
        "weapon_shape": "large forward-facing circular orange dish on pivot mount",
        "weapon_size": "large",
    },
    "microwave": {
        "material": "heat-resistant alloy panels, cooling fin arrays, power conduit housing, thermal seals",
        "accent_hex": "#D06030",
        "accent_name": "heat shimmer orange",
        "body_desc": "low boxy generator unit, cooling fan grille on side, exhaust heat shimmer, power conduit bundle",
        "body_height": "short",
        "ground_desc": "heat-shielded reinforced slab",
        "weapon_desc": "flat panel directed energy emitter, heat grid face, cooling fins on sides",
        "weapon_shape": "flat rectangular panel with grid face on pivot",
        "weapon_size": "large",
    },
}

# ---------------------------------------------------------------------------
# Tier 5 Evo Variants -- 3 upgrade paths (a, b, c) per tower
# ---------------------------------------------------------------------------
# Each variant inherits parent tower's material/accent/grit.
# File output: towers/{parent}/tier5{a|b|c}_turret_{dir}.png

TIER5_VARIANTS = {
    # --- Rubber Bullet ---
    "rubber_bullet_a5": {
        "parent": "rubber_bullet",
        "name": "DEADSHOT",
        "weapon_desc": "long-barrel precision sniper rifle with telescopic scope, bipod mount, bolt-action mechanism",
        "weapon_shape": "long narrow barrel extending forward-right, scope on top rail, folding bipod legs",
        "weapon_size": "large",
        "fire_desc": "bright muzzle flash at barrel tip, smoke trail, scope glint, recoil kickback",
    },
    "rubber_bullet_b5": {
        "parent": "rubber_bullet",
        "name": "BULLET HELL",
        "weapon_desc": "multi-barrel rotary minigun, ammo belt feed from side, spinning barrel cluster, brass casing ejection port",
        "weapon_shape": "rotating barrel cluster extending forward-right, side-mounted ammo drum, heavy rotating assembly",
        "weapon_size": "large",
        "fire_desc": "spinning barrels with continuous muzzle flash stream, brass casings flying, ammo belt feeding rapidly, barrel glow",
    },
    "rubber_bullet_c5": {
        "parent": "rubber_bullet",
        "name": "EXPERIMENTAL ORDNANCE",
        "weapon_desc": "exotic energy launcher, glowing plasma chamber, experimental tech housing, capacitor coils",
        "weapon_shape": "bulky rectangular housing with glowing front aperture, side capacitor banks, experimental wiring",
        "weapon_size": "large",
        "fire_desc": "bright plasma bolt launching from aperture, glowing energy charge, capacitor discharge arcs, pulsing core",
    },
    # --- Tear Gas ---
    "tear_gas_a5": {
        "parent": "tear_gas",
        "name": "NERVE AGENT DEPLOYER",
        "weapon_desc": "massive chemical mortar array, bio-hazard housing, dripping toxic residue, sealed launch tubes",
        "weapon_shape": "triple mortar tube cluster angled upward, hazmat sealed housing, drip stains on sides",
        "weapon_size": "large",
        "fire_desc": "green toxic smoke billowing from tubes, canister launching upward with smoke trail, chemical splash drips",
    },
    "tear_gas_b5": {
        "parent": "tear_gas",
        "name": "CARPET GASSER",
        "weapon_desc": "wide carpet-bomb launcher rack, dozens of small launch tubes in grid pattern, area saturation system",
        "weapon_shape": "wide flat rectangular rack with rows of small tubes, grid formation, side-loading mechanism",
        "weapon_size": "large",
        "fire_desc": "multiple canisters launching simultaneously from grid, smoke trails fanning out, launch flash from each tube",
    },
    "tear_gas_c5": {
        "parent": "tear_gas",
        "name": "PANIC INDUCER",
        "weapon_desc": "gas emitter with pulsing red fear strobe light, skull warning markers, psychological warfare device",
        "weapon_shape": "compact emitter with rotating red strobe on top, skull decals, gas vent nozzle forward",
        "weapon_size": "medium",
        "fire_desc": "intense red strobe flashing, thick yellow-green gas cloud pouring from nozzle, fear aura glow",
    },
    # --- Taser Grid ---
    "taser_grid_a5": {
        "parent": "taser_grid",
        "name": "ARC REACTOR",
        "weapon_desc": "massive tesla coil spire, crackling arc reactor core, chain lightning arcs, high voltage capacitor banks",
        "weapon_shape": "tall vertical tesla coil spire, glowing core sphere, arcing electricity between prongs",
        "weapon_size": "large",
        "fire_desc": "massive chain lightning bolt shooting outward, bright electric arcs between prongs, core sphere blazing white-blue",
    },
    "taser_grid_b5": {
        "parent": "taser_grid",
        "name": "EMP GRID",
        "weapon_desc": "triple-prong beam splitter, neural disruption emitter, branching electrode array, pulse generator",
        "weapon_shape": "three-pronged electrode array fanning outward, central pulse emitter, branching conductor tips",
        "weapon_size": "large",
        "fire_desc": "branching electric beams splitting from each prong, EMP pulse wave expanding outward, blue discharge glow",
    },
    "taser_grid_c5": {
        "parent": "taser_grid",
        "name": "BLACKOUT FIELD",
        "weapon_desc": "electromagnetic dome generator, pulsing suppression field rings, EMP coil housing",
        "weapon_shape": "dome-shaped emitter with concentric ring elements, pulsing field effect, compact base unit",
        "weapon_size": "medium",
        "fire_desc": "expanding electromagnetic dome pulse, concentric rings radiating outward, blue-white suppression field flash",
    },
    # --- Water Cannon ---
    "water_cannon_a5": {
        "parent": "water_cannon",
        "name": "TSUNAMI CANNON",
        "weapon_desc": "triple-barrel industrial fire hose array, massive water tank, pressure gauges maxed, reinforced piping",
        "weapon_shape": "three parallel large nozzles extending forward-right, manifold connector, heavy gauge pipes",
        "weapon_size": "large",
        "fire_desc": "three powerful water jets blasting forward, massive spray and mist cloud, water splashing back, pipes shaking",
    },
    "water_cannon_b5": {
        "parent": "water_cannon",
        "name": "INDUSTRIAL WASHER",
        "weapon_desc": "high-pressure cutting jet nozzle, industrial cutter housing, precision spray head, extreme PSI gauge",
        "weapon_shape": "narrow focused nozzle on precision gimbal, compact high-pressure housing, fine spray tip",
        "weapon_size": "medium",
        "fire_desc": "razor-thin high-pressure water beam cutting forward, fine mist spray, precision targeting laser line",
    },
    "water_cannon_c5": {
        "parent": "water_cannon",
        "name": "HYPOTHERMIA FIELD",
        "weapon_desc": "cryo-emitter device, frost-covered nozzle, ice crystal formation, freezing mist vents, coolant tank",
        "weapon_shape": "frost-encrusted emitter head with ice crystal buildup, coolant pipes, freezing mist cloud",
        "weapon_size": "large",
        "fire_desc": "freezing cryo blast spraying forward, ice crystals forming in air, thick frost mist, blue cold glow",
    },
    # --- Surveillance ---
    "surveillance_a5": {
        "parent": "surveillance",
        "name": "PANOPTICON",
        "weapon_desc": "massive multi-dish radar array, drone launcher bay, camera cluster dome, full spectrum sensor suite",
        "weapon_shape": "large radar dish with smaller dishes around it, camera dome on top, drone bay hatch",
        "weapon_size": "large",
        "fire_desc": "scanning beam sweeping from dish, drone launching from bay, all cameras glowing red, radar pulse rings",
    },
    "surveillance_b5": {
        "parent": "surveillance",
        "name": "SOCIAL CREDIT ENGINE",
        "weapon_desc": "server rack antenna, scanning beam projector, database terminal screens, facial recognition lens",
        "weapon_shape": "vertical server rack with antenna array, forward scanning beam lens, side display screens",
        "weapon_size": "large",
        "fire_desc": "bright scanning beam projecting forward, screens displaying red warning data, facial recognition targeting box",
    },
    "surveillance_c5": {
        "parent": "surveillance",
        "name": "MINISTRY OF TRUTH",
        "weapon_desc": "propaganda loudspeaker array with screens, broadcast antenna, hypnotic display panel, signal emitter",
        "weapon_shape": "cluster of loudspeaker horns around central display screen, broadcast antenna mast on top",
        "weapon_size": "large",
        "fire_desc": "loudspeakers blasting visible sound waves, screen displaying hypnotic spiral, broadcast signal rings pulsing",
    },
    # --- Pepper Spray ---
    "pepper_spray_a5": {
        "parent": "pepper_spray",
        "name": "WEAPONIZED CAPSAICIN",
        "weapon_desc": "oversized industrial chemical sprayer, concentrated nozzle, pressurized tank, drip stains, hazmat seals",
        "weapon_shape": "large pressurized canister with industrial spray nozzle extending forward, dripping residue",
        "weapon_size": "large",
        "fire_desc": "thick orange-red chemical spray blasting from nozzle, pressurized mist cloud, dripping residue splatter",
    },
    "pepper_spray_b5": {
        "parent": "pepper_spray",
        "name": "CLOUD CHAMBER",
        "weapon_desc": "multi-directional fog dispersal unit, radial nozzle ring, gas cloud emitter, 360-degree coverage",
        "weapon_shape": "radial ring of outward-facing nozzles around central hub, fog emission vents",
        "weapon_size": "large",
        "fire_desc": "orange pepper fog spraying from all nozzles radially, expanding cloud ring, choking mist filling area",
    },
    "pepper_spray_c5": {
        "parent": "pepper_spray",
        "name": "SYNTHETIC ALLERGEN",
        "weapon_desc": "bio-lab emitter pod, research equipment housing, biohazard seals, specimen containment vials",
        "weapon_shape": "sealed lab pod with biohazard markings, emitter aperture forward, containment vial rack on side",
        "weapon_size": "medium",
        "fire_desc": "green-orange bio-agent mist spraying from aperture, biohazard warning glow, containment vials bubbling",
    },
    # --- LRAD ---
    "lrad_a5": {
        "parent": "lrad",
        "name": "BROWN NOTE",
        "weapon_desc": "oversized parabolic dish, massive amplifier stack, devastating concentric sound rings, subwoofer array",
        "weapon_shape": "huge forward-facing parabolic dish with concentric ring elements, amplifier bank behind",
        "weapon_size": "large",
        "fire_desc": "massive visible sound wave blast from dish, concentric pressure rings expanding forward, air distortion shimmer",
    },
    "lrad_b5": {
        "parent": "lrad",
        "name": "RESONANCE CASCADE",
        "weapon_desc": "triple harmonic dish array, resonance tuning forks, vibration wave emitter, harmonic oscillator",
        "weapon_shape": "three offset dishes in triangular formation, tuning fork prongs between, vibration wave lines",
        "weapon_size": "large",
        "fire_desc": "triple harmonic sound beams converging forward, resonance fork vibration blur, intersecting wave patterns",
    },
    "lrad_c5": {
        "parent": "lrad",
        "name": "SUBLIMINAL ARRAY",
        "weapon_desc": "mind-control dish with spiral pattern, eerie green glow, hypnotic emitter, signal modulator",
        "weapon_shape": "dish with spiral pattern on face, green glowing center, signal modulator box on back",
        "weapon_size": "medium",
        "fire_desc": "spinning hypnotic spiral projecting forward, eerie green beam, mind-control signal waves, pulsing glow",
    },
    # --- Microwave ---
    "microwave_a5": {
        "parent": "microwave",
        "name": "DEATH RAY",
        "weapon_desc": "massive overcharged beam cannon, heat shimmer distortion, cooling fin overload, plasma core glow",
        "weapon_shape": "long heavy barrel cannon with glowing aperture, stacked cooling fins, overheating vents",
        "weapon_size": "large",
        "fire_desc": "intense orange-white heat beam blasting from barrel, heat shimmer distortion waves, cooling fins glowing red-hot",
    },
    "microwave_b5": {
        "parent": "microwave",
        "name": "PRECISION DENIAL",
        "weapon_desc": "pinpoint laser emitter, precision targeting optics, surgical beam aperture, compact focusing lens",
        "weapon_shape": "narrow precision barrel with targeting optics on top, compact lens assembly at tip",
        "weapon_size": "medium",
        "fire_desc": "thin precise red laser beam firing forward, targeting reticle projected, lens flare at aperture",
    },
    "microwave_c5": {
        "parent": "microwave",
        "name": "COOKING FIELD",
        "weapon_desc": "wide multi-panel heat array, radiant heat zone emitter, thermal grid face, area denial system",
        "weapon_shape": "wide flat multi-panel array with thermal grid pattern, heat shimmer above, side cooling ducts",
        "weapon_size": "large",
        "fire_desc": "all panels glowing bright orange-red, radiant heat waves emanating forward, thermal distortion shimmer zone",
    },
}

# ---------------------------------------------------------------------------
# Enemy Data
# ---------------------------------------------------------------------------

ENEMIES = {
    "rioter": {
        "desc": "basic civilian protestor, hoodie and jeans, bandana face mask, "
                "carrying crude protest sign, lean aggressive stance",
        "size": (32, 32),
    },
    "masked": {
        "desc": "gas mask wearing protestor, tactical vest over hoodie, "
                "medium build, determined stance, goggles and respirator",
        "size": (32, 32),
    },
    "shield_wall": {
        "desc": "large riot shield carrier, heavy improvised armor, "
                "makeshift plywood and metal shield, slow heavy stance, bulky",
        "size": (32, 32),
    },
    "molotov": {
        "desc": "slim agile protestor, arm raised holding bottle with lit rag, "
                "fire glow from molotov, bandana mask, light fast build",
        "size": (32, 32),
    },
    "drone_op": {
        "desc": "tech-savvy protestor with drone controller, "
                "backpack with antenna, goggles, screen glow",
        "size": (32, 32),
    },
    "goth_protestor": {
        "desc": "goth punk girl, black hair, pale skin, "
                "black tank top, short black skirt, fishnet stockings, combat boots, "
                "spiked choker, dark makeup, confident stride",
        "size": (32, 32),
    },
    "street_medic": {
        "desc": "first aid cross armband, medical backpack, face mask, "
                "running support posture, white cross on arm",
        "size": (32, 32),
    },
    "armored_van": {
        "desc": "improvised armored vehicle, welded metal plates on van, "
                "barricade ram front, small viewport slits, heavy dark silhouette",
        "size": (32, 32),
    },
    "infiltrator": {
        "desc": "dark hooded figure, crouched sneaking pose, "
                "shadow-blend clothing, very dark body",
        "size": (32, 32),
    },
    "blonde_protestor": {
        "desc": "blonde girl, long flowing blonde hair, "
                "crop top, shorts, sneakers, holding megaphone, "
                "sassy confident walk, bright hair contrasting dark outfit",
        "size": (32, 32),
    },
    "tunnel_rat": {
        "desc": "hunched figure with mining helmet, goggles and dust mask, "
                "digging tools on back, low crouching pose, dirt-stained, headlamp glow",
        "size": (32, 32),
    },
    "union_boss": {
        "desc": "large intimidating figure, hard hat and hi-vis vest, "
                "megaphone in hand, commanding presence, heavy build",
        "size": (32, 32),
    },
    "journalist": {
        "desc": "reporter with press badge, camera or notepad, "
                "professional clothing, neutral stance, media ID lanyard",
        "size": (32, 32),
    },
    "grandma": {
        "desc": "elderly woman with handbag and headscarf, "
                "hunched posture, determined expression, walking stick, "
                "old-fashioned clothing",
        "size": (32, 32),
    },
    "family": {
        "desc": "parent and child holding hands, civilian clothes, "
                "protective posture, ordinary family look, "
                "the child slightly behind the parent",
        "size": (32, 32),
    },
    "student": {
        "desc": "young person with backpack, university hoodie, "
                "carrying books or laptop, idealistic expression, "
                "sneakers and jeans, youthful energy",
        "size": (32, 32),
    },
    "drummer": {
        "desc": "protestor carrying large portable bass drum strapped to chest, "
                "both arms raised with drumsticks pounding the drum, "
                "bandana headband, tank top, cargo pants, heavy boots, "
                "muscular arms, rhythmic marching stance",
        "size": (32, 32),
    },
    "sign_stop": {
        "desc": "protestor holding large cardboard sign above head with bold STOP text, "
                "hoodie, jeans, sneakers, angry shouting expression, "
                "both hands gripping sign pole, marching forward",
        "size": (32, 32),
    },
    "sign_peace": {
        "desc": "protestor carrying big hand-painted peace symbol sign on wooden stick, "
                "tie-dye shirt, beanie hat, round glasses, "
                "one hand holding sign high, relaxed walking pose",
        "size": (32, 32),
    },
    "sign_fist": {
        "desc": "protestor waving large protest banner with painted raised fist drawing, "
                "leather jacket, ripped jeans, combat boots, "
                "defiant stance, sign held at angle while marching",
        "size": (32, 32),
    },
    "press_drone": {
        "desc": "small quadcopter drone, four rotor arms, compact dark body, "
                "red camera lens underneath, spinning propeller blur, "
                "flying aerial vehicle seen from above, news media drone",
        "size": (32, 32),
    },
    "news_helicopter": {
        "desc": "small news helicopter, main rotor on top, tail boom, "
                "red and white paint scheme with NEWS marking, "
                "cockpit windshield, flying aerial vehicle seen from above, "
                "skids landing gear underneath",
        "size": (32, 32),
    },
}

# ---------------------------------------------------------------------------
# Boss Data
# ---------------------------------------------------------------------------

BOSSES = {
    "demagogue": {
        "desc": "charismatic leader on elevated platform with megaphone, "
                "long coat flowing, dramatic pointing gesture, propaganda banner",
    },
    "hacktivist": {
        "desc": "hooded hacker figure with floating holographic screens, "
                "green terminal text glow, typing gesture, digital glitch effects",
    },
    "barricade": {
        "desc": "massive walking barricade structure, humanoid shape made of "
                "welded metal sheets, car doors, wooden planks, rebar",
    },
    "influencer": {
        "desc": "flashy narcissistic figure with ring light halo, "
                "phone held up for selfie, designer protest outfit",
    },
    "ghost_protocol": {
        "desc": "flickering translucent figure, phasing in and out of reality, "
                "glitch visual effects, teleport afterimage trail",
    },
}

# ---------------------------------------------------------------------------
# Projectile Data
# ---------------------------------------------------------------------------

PROJECTILES = {
    "rubber_bullet": ("small silver bullet with tracer trail, kinetic projectile", 8),
    "tear_gas": ("lobbed cylindrical canister, chemical green, smoke trail", 12),
    "water_blast": ("pressurized water stream burst, cool blue to white, splash", 16),
    "electric_arc": ("jagged lightning bolt, electric blue, bright core, spark", 12),
    "sonic_wave": ("concentric arc wave lines, expanding rings, amber, ripple", 16),
    "heat_beam": ("straight directed energy beam, shimmer heat haze, orange core", 16),
    "pepper_spray": ("expanding aerosol cone, mist particles, green to yellow-green", 16),
    "surveillance_ping": ("scanning pulse, radar blip, terminal green, circular ripple", 8),
}

# ---------------------------------------------------------------------------
# Effect Data
# ---------------------------------------------------------------------------

EFFECTS = {
    "explosion_kinetic": ("bullet impact burst, debris spray, flash, spark, smoke", 16),
    "explosion_chemical": ("gas cloud expansion, chemical reaction, green cloud", 32),
    "explosion_fire": ("fireball explosion, flash core to fire bloom, smoke trail", 32),
    "explosion_electric": ("electrical discharge burst, arc flash, blue core, lightning", 24),
    "explosion_water": ("water impact splash, concentric droplet ring, mist", 24),
    "explosion_sonic": ("sonic shockwave ring, concentric expanding circles, amber", 24),
    "explosion_energy": ("directed energy flash, beam impact, purple to white, shimmer", 24),
    "explosion_cyber": ("digital glitch burst, fragmented pixels, data corruption, green", 16),
    "status_stun": ("spinning stars above head, dazed indicator, electric blue and yellow", 16),
    "status_freeze": ("ice crystal overlay, frost particles, cryo blue, ice formation", 16),
    "status_burn": ("small flame wisps, burning indicator, fire orange, ember, smoke", 16),
    "status_poison": ("toxic bubble particles rising, corrosion drops, green bubbles", 16),
    "status_shield": ("hexagonal energy shield overlay, barrier glow, shield blue", 16),
}

# ---------------------------------------------------------------------------
# Tile Data
# ---------------------------------------------------------------------------

TILES = {
    "concrete_a": "plain solid grey concrete, very uniform, almost flat color, extremely low contrast",
    "concrete_b": "plain solid dark grey concrete, very uniform, almost flat color, extremely low contrast",
    "concrete_c": "plain solid grey concrete, very slight tonal variation, extremely low contrast, nearly flat",
}

# ---------------------------------------------------------------------------
# City Building Data
# ---------------------------------------------------------------------------

BUILDINGS = {
    "government_dome": {
        "desc": "imposing government palace, Soviet neoclassical, large golden onion dome on top, "
                "massive columns at entrance, floodlit stone facade, barricades at base, "
                "flag on dome, institutional grandeur, night scene",
        "size": (192, 192),
    },
    "panelka_tall_a": {
        "desc": "tall Soviet panelka apartment block, 10+ stories, repeating window grid, "
                "crumbling prefab concrete, some windows dim yellow lit, satellite dishes, "
                "brutalist rectangular tower, night scene",
        "size": (96, 160),
    },
    "panelka_tall_b": {
        "desc": "tall dark Soviet apartment tower, 12 stories, narrow building, "
                "few lit windows, broken balconies, antenna on roof, "
                "concrete decay, urban neglect, night scene",
        "size": (80, 160),
    },
    "panelka_wide": {
        "desc": "wide Soviet apartment block, 5 stories, long horizontal form, "
                "prefab concrete panels, some windows boarded, graffiti, "
                "dim balcony lights, urban decay, night scene",
        "size": (160, 96),
    },
    "rooftop_fg_a": {
        "desc": "rooftop of concrete building seen from above at angle, flat roof, "
                "air vents, water tank, antenna mast, gravel surface, "
                "concrete parapet edge, night scene",
        "size": (192, 64),
    },
    "rooftop_fg_b": {
        "desc": "rooftop edge of apartment building from above, concrete parapet, "
                "satellite dishes, pipes, chimney, seen from slightly above, "
                "urban rooftop clutter, night scene",
        "size": (160, 48),
    },
    "factory": {
        "desc": "dark industrial factory building, tall smokestack chimney with faint smoke, "
                "corrugated metal walls, small dirty windows, loading dock, "
                "Soviet industrial brutalism, night scene",
        "size": (128, 128),
    },
    "panelka_short": {
        "desc": "short squat Soviet apartment block, 4 stories, wide and low, "
                "prefab panels, laundry on balconies, dim lights, "
                "cracked facade, urban housing, night scene",
        "size": (128, 80),
    },
    "water_tower": {
        "desc": "tall concrete water tower, cylindrical tank on stilts, "
                "Soviet industrial, ladder rungs, rusty metal, "
                "single red warning light on top, night scene",
        "size": (48, 128),
    },
    "guard_booth": {
        "desc": "small military guard booth checkpoint, concrete walls, "
                "metal roof, single bright light, barrier gate arm, "
                "sandbags at base, authoritarian outpost, night scene",
        "size": (64, 64),
    },
    "church_spire": {
        "desc": "old orthodox church with tall spire and cross on top, "
                "dark stone walls, narrow windows, scaffolding for repairs, "
                "abandoned religious building, night scene",
        "size": (64, 160),
    },
    # --- Vehicles ---
    "police_bus": {
        "desc": "riot police transport bus, dark blue armored bus, mesh window guards, "
                "side door open, heavy tires, OMON markings, parked on flat ground, "
                "isometric vehicle, night scene",
        "size": (96, 64),
    },
    "police_car": {
        "desc": "police patrol car, dark blue sedan with lightbar on roof, "
                "white stripe, parked on flat ground, "
                "isometric vehicle, night scene",
        "size": (64, 48),
    },
    # --- Props / barriers ---
    "barricade": {
        "desc": "heavy concrete jersey barrier with metal fence on top, "
                "police riot barricade, orange warning stripes, "
                "sitting on flat ground, isometric object, night scene",
        "size": (64, 48),
    },
    "barbed_wire": {
        "desc": "coiled razor wire barrier on metal posts, concertina wire, "
                "military checkpoint obstacle, sitting on flat ground, "
                "isometric object, night scene",
        "size": (96, 32),
    },
    "playground_soviet": {
        "desc": "broken Soviet playground, rusty metal climbing frame, "
                "old carousel, cracked concrete base, bent swing set, "
                "urban decay, sitting on flat ground, isometric diorama, night scene",
        "size": (128, 96),
    },
    # --- More buildings ---
    "khrushchyovka": {
        "desc": "classic Soviet khrushchyovka 5-story apartment block, long horizontal, "
                "uniform window rows, prefab concrete panels, flat roof, "
                "few dim lights, urban housing, night scene",
        "size": (160, 96),
    },
    "apartment_tower": {
        "desc": "Soviet 16-story residential tower, brutalist concrete, "
                "narrow and tall, repeating balconies, antenna on roof, "
                "scattered lit windows, urban monolith, night scene",
        "size": (64, 192),
    },
    # --- Road elements (isometric, joinable on tile grid) ---
    "road_ew": {
        "desc": "straight asphalt road going left-right, isometric diamond tile, "
                "worn lane markings, cracked surface, puddles, "
                "flat road surface only, no buildings, night scene",
        "size": (128, 64),
    },
    "road_ns": {
        "desc": "straight asphalt road going up-down, isometric diamond tile, "
                "worn center line, cracked asphalt, flat road surface only, "
                "no buildings, night scene",
        "size": (128, 64),
    },
    "road_cross": {
        "desc": "asphalt crossroads intersection, isometric diamond tile, "
                "faded lane markings, cracked surface, manhole cover in center, "
                "flat road surface only, no buildings, night scene",
        "size": (128, 64),
    },
    "road_corner": {
        "desc": "asphalt road corner turn, isometric diamond tile, "
                "worn lane markings curving, cracked surface, "
                "flat road surface only, no buildings, night scene",
        "size": (128, 64),
    },
}

# ---------------------------------------------------------------------------
# Animated Detail Data
# ---------------------------------------------------------------------------

ANIMATED_DETAILS = {
    "burning_barrel": {
        "desc": "fire flickering in oil drum barrel, flames dancing, "
                "warm orange glow, ember sparks rising, hobo fire",
        "size": (64, 64),
        "frames": 4,
    },
    "waving_flag": {
        "desc": "cloth flag waving in wind, fabric ripple motion, "
                "red flag on pole, protest banner, cloth wave cycle",
        "size": (64, 64),
        "frames": 4,
    },
    "neon_sign": {
        "desc": "flickering neon sign, buzzing light on-off cycle, "
                "broken electric sign, intermittent glow, urban decay",
        "size": (64, 64),
        "frames": 4,
    },
}

# ---------------------------------------------------------------------------
# Props Data
# ---------------------------------------------------------------------------

PROPS = {
    "barricade": ("concrete jersey barrier, riot police barricade, caution stripe", 32, 24),
    "burnt_car": ("burnt-out car wreck, smashed windows, fire damage, charred metal", 48, 32),
    "floodlight": ("tall portable floodlight on tripod stand, harsh light cone", 16, 32),
    "razor_wire": ("coiled razor wire barrier, military grade, steel, sharp gleam", 32, 8),
    "rubble_small": ("small rubble pile, concrete chunks, dust", 16, 16),
    "rubble_large": ("large collapsed building debris, concrete and rebar", 32, 24),
    "dumpster": ("metal dumpster, graffiti, dented, urban decay", 24, 16),
    "street_lamp": ("broken street lamp, shattered bulb, bent pole, urban ruin", 8, 32),
    "signs_ground": ("discarded protest signs on ground, trampled cardboard", 16, 8),
    "traffic_cone": ("orange traffic cone, knocked over, urban clutter", 8, 8),
    "burning_barrel": ("burning oil drum, fire inside, warm glow, hobo fire", 16, 16),
    "sandbags": ("sandbag wall fortification, military barrier, stacked bags", 32, 16),
}

# ---------------------------------------------------------------------------
# UI Icon Data
# ---------------------------------------------------------------------------

UI_ICONS = {
    "tower_rubber_bullet": "simplified rubber bullet turret silhouette, dual barrels, kinetic silver",
    "tower_tear_gas": "simplified grenade launcher rack silhouette, chemical green accent",
    "tower_taser_grid": "simplified tesla coil silhouette, electric blue glow",
    "tower_water_cannon": "simplified water hose turret silhouette, cool blue accent",
    "tower_surveillance": "simplified satellite dish silhouette, terminal green glow",
    "tower_pepper_spray": "simplified spray nozzle silhouette, chemical orange accent",
    "tower_lrad": "simplified speaker dish silhouette, amber warning glow",
    "tower_microwave": "simplified energy panel silhouette, heat shimmer orange",
    "dmg_kinetic": "bullet shape icon, kinetic silver, simple bold",
    "dmg_chemical": "droplet/flask icon, chemical green, hazard symbol",
    "dmg_hydraulic": "water wave icon, cool blue, pressure burst",
    "dmg_electric": "lightning bolt icon, electric blue, sharp edges",
    "dmg_sonic": "sound wave rings icon, amber, concentric arcs",
    "dmg_energy": "beam ray icon, purple, directed energy",
    "dmg_cyber": "circuit chip icon, terminal green, digital",
    "dmg_psychological": "eye icon, slate gray, surveillance feel",
    "budget": "authoritarian eagle stamp coin, amber currency, institutional feel",
    "approval": "approval meter shield badge, green when high, official insignia",
    "incident": "wave counter exclamation, warning amber, alert indicator",
    "speed_1x": "single arrow play button, terminal green, speed control",
    "speed_2x": "double arrow fast forward, terminal green, speed control",
    "speed_3x": "triple arrow fastest, terminal green, speed control",
    "upgrade": "upward arrow, amber highlight, improvement indicator",
    "sell": "downward arrow with coin, red accent, sell/demolish",
    "locked": "padlock icon, gunmetal gray, locked state",
    "ability_airstrike": "crosshair with explosion, emergency red, airstrike target",
    "ability_freeze": "snowflake crystal, cryo blue, flash freeze",
    "ability_funding": "double coin stack, bright amber, emergency funding",
}


# ---------------------------------------------------------------------------
# Generation Functions
# ---------------------------------------------------------------------------

def _gen_turret_ref(client: PixelLabClient, name: str, info: dict) -> tuple[str, bytes]:
    """Generate a single turret reference image. Returns (name, image_bytes)."""
    cop_prompt = info.get("cop_prompt")
    if cop_prompt:
        print(f"  Generating cop figure reference for {name} (SE)...")
        prompt = cop_prompt
        neg = NEGATIVE
    else:
        print(f"  Generating turret reference for {name} (SE)...")
        prompt = build_turret_prompt(info)
        neg = TURRET_NEGATIVE
    img = client.generate_image(
        prompt,
        64, 64,
        isometric=True,
        negative_description=neg,
    )
    if img:
        img = remove_background(img)
        if cop_prompt:
            img = remove_ground_stain(img)
    save_image(img, f"towers/{name}/turret_ref.png", open_viewer=False)
    return (name, img)


def _gen_turret_rotations(client: PixelLabClient, name: str, turret_ref: bytes,
                           prefix: str = "turret",
                           clean_stains: bool = False) -> None:
    """Generate 8 rotations for a turret from its reference image.

    PixelLab's rotate_8_directions returns east/west swapped directions.
    We remap: swap NE↔NW, E↔W, SE↔SW to correct this.

    prefix: file prefix — "turret" for idle, "turret_fire" for firing pose.
    clean_stains: if True, run remove_ground_stain on each rotation output.
    """
    # API returns [s, sw, w, nw, n, ne, e, se] but E/W axis is flipped.
    # Corrected labels for indices 0-7:
    CORRECTED_DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]

    print(f"  Generating 8 rotations for {name} ({prefix})...")
    try:
        rotations = client.rotate_8_directions(
            img_to_b64(turret_ref), 64, 64,
            view="low top-down",
            method="rotate_character",
        )
        for i, (_api_dir, img_data) in enumerate(rotations):
            corrected_dir = CORRECTED_DIRS[i] if i < len(CORRECTED_DIRS) else _api_dir
            if clean_stains:
                img_data = remove_ground_stain(img_data)
            save_image(img_data, f"towers/{name}/{prefix}_{corrected_dir}.png", open_viewer=False)
        print(f"  Got {len(rotations)} rotations for {name}/{prefix} (direction-corrected)")
    except Exception as e:
        print(f"  ERROR generating rotations for {name}/{prefix}: {e}")
        print(f"  Saving SE reference as fallback for all directions")
        for d in ["s", "sw", "w", "nw", "n", "ne", "e", "se"]:
            save_image(turret_ref, f"towers/{name}/{prefix}_{d}.png", open_viewer=False)


def _gen_fire_ref(client: PixelLabClient, name: str, info: dict,
                   idle_ref: bytes | None = None) -> tuple[str, bytes]:
    """Generate a firing-pose reference image using idle ref as init_image for consistency.

    Returns (name, image_bytes).
    """
    fire_prompt = info.get("cop_fire_prompt")
    if not fire_prompt:
        return (name, None)
    init_b64 = img_to_b64(idle_ref) if idle_ref else None
    label = " (with idle ref as init)" if init_b64 else ""
    print(f"  Generating fire pose reference for {name} (SE){label}...")
    img = client.generate_image(
        fire_prompt,
        64, 64,
        isometric=True,
        negative_description=NEGATIVE,
        init_image_b64=init_b64,
        init_image_strength=250.0,  # rough color guidance — keep palette, allow pose change
    )
    if img:
        img = remove_background(img)
        img = remove_ground_stain(img)
    save_image(img, f"towers/{name}/turret_fire_ref.png", open_viewer=False)
    return (name, img)


def gen_turrets(client: PixelLabClient, names: list[str] | None = None):
    """Phase: Generate turret references (SE) then 8-rotation for each tower type."""
    tower_names = names or list(TOWERS.keys())
    total = len(tower_names)
    print(f"\n=== TURRETS ({total} towers x 8 directions = {total * 8} sprites) ===\n")

    # Phase A: Generate all turret references in parallel
    print("Phase A: Generating turret references...")
    ref_tasks = [
        (name, _gen_turret_ref, (client, name, TOWERS[name]), {})
        for name in tower_names
    ]
    ref_results = run_parallel(ref_tasks)

    # Collect idle refs for fire pose init_image
    idle_ref_map: dict[str, bytes] = {}
    # Phase B: Generate all 8-direction rotations in parallel
    print("\nPhase B: Generating 8-direction rotations...")
    rot_tasks = []
    for result in ref_results:
        if result is None:
            continue
        name, turret_ref = result
        if not turret_ref:
            print(f"  ERROR: No turret reference generated for {name}, skipping rotations")
            continue
        idle_ref_map[name] = turret_ref
        is_cop = bool(TOWERS[name].get("cop_prompt"))
        rot_tasks.append(
            (name, _gen_turret_rotations, (client, name, turret_ref, "turret", is_cop), {})
        )
    if rot_tasks:
        run_parallel(rot_tasks)

    # Phase C: Generate fire pose refs for towers that have cop_fire_prompt
    fire_names = [n for n in tower_names if TOWERS[n].get("cop_fire_prompt")]
    if fire_names:
        print(f"\nPhase C: Generating fire pose references ({len(fire_names)} towers)...")
        fire_ref_tasks = [
            (name, _gen_fire_ref, (client, name, TOWERS[name], idle_ref_map.get(name)), {})
            for name in fire_names
        ]
        fire_ref_results = run_parallel(fire_ref_tasks)

        # Phase D: Generate fire pose 8-direction rotations
        print("\nPhase D: Generating fire pose 8-direction rotations...")
        fire_rot_tasks = []
        for result in fire_ref_results:
            if result is None:
                continue
            name, fire_ref = result
            if not fire_ref:
                print(f"  ERROR: No fire pose reference for {name}, skipping")
                continue
            fire_rot_tasks.append(
                (name, _gen_turret_rotations, (client, name, fire_ref, "turret_fire", True), {})
            )
        if fire_rot_tasks:
            run_parallel(fire_rot_tasks)


# ---------------------------------------------------------------------------
# Evo Turret Generation (Tier 5 variants)
# ---------------------------------------------------------------------------

def _gen_evo_turret_ref(client: PixelLabClient, variant_key: str,
                         variant: dict) -> tuple[str, bytes]:
    """Generate a single evo turret SE reference image.

    Uses the parent tower's existing turret_ref.png as init_image for style
    consistency (low strength so the new weapon design dominates).
    Returns (variant_key, image_bytes).
    """
    parent_name = variant["parent"]
    parent = TOWERS[parent_name]
    path_letter = variant_key.split("_")[-1][0]  # e.g. "a" from "rubber_bullet_a5"
    print(f"  Generating evo turret reference for {variant_key} ({variant['name']}, SE)...")

    prompt = build_evo_turret_prompt(variant, parent, path_letter)

    # Use parent's turret ref as init_image for style consistency
    parent_ref_path = SPRITES_DIR / "towers" / parent_name / "turret_ref.png"
    init_b64 = None
    if parent_ref_path.exists():
        with open(parent_ref_path, "rb") as f:
            init_b64 = base64.b64encode(f.read()).decode()
        print(f"    Using parent turret ref as init_image (strength 300)")

    img = client.generate_image(
        prompt,
        64, 64,
        isometric=True,
        negative_description=TURRET_NEGATIVE,
        init_image_b64=init_b64,
        init_image_strength=300.0,  # light guidance — keep palette, allow new weapon
    )
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{parent_name}/tier5{path_letter}_turret_ref.png", open_viewer=False)
    return (variant_key, img)


def _gen_evo_fire_ref(client: PixelLabClient, variant_key: str,
                       variant: dict, idle_ref: bytes | None = None) -> tuple[str, bytes]:
    """Generate a firing-pose evo turret reference using idle ref as init_image.

    Returns (variant_key, image_bytes).
    """
    parent_name = variant["parent"]
    parent = TOWERS[parent_name]
    path_letter = variant_key.split("_")[-1][0]
    init_b64 = img_to_b64(idle_ref) if idle_ref else None
    label = " (with idle ref as init)" if init_b64 else ""
    print(f"  Generating evo fire pose for {variant_key} ({variant['name']}, SE){label}...")

    prompt = build_evo_turret_fire_prompt(variant, parent, path_letter)

    img = client.generate_image(
        prompt,
        64, 64,
        isometric=True,
        negative_description=TURRET_NEGATIVE,
        init_image_b64=init_b64,
        init_image_strength=250.0,  # keep shape, allow firing effects
    )
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{parent_name}/tier5{path_letter}_turret_fire_ref.png", open_viewer=False)
    return (variant_key, img)


def gen_evo_turrets(client: PixelLabClient, names: list[str] | None = None,
                     variants_filter: list[str] | None = None):
    """Phase: Generate tier 5 evo turret references (SE) then 8-rotations.

    Args:
        names: filter by parent tower names (e.g. ["rubber_bullet"])
        variants_filter: filter by specific variant keys (e.g. ["rubber_bullet_a5"])
    """
    # Determine which variants to generate
    if variants_filter:
        variant_keys = [k for k in variants_filter if k in TIER5_VARIANTS]
        for k in variants_filter:
            if k not in TIER5_VARIANTS:
                print(f"  WARNING: Unknown variant '{k}', skipping. "
                      f"Available: {', '.join(TIER5_VARIANTS.keys())}")
    elif names:
        variant_keys = [k for k, v in TIER5_VARIANTS.items() if v["parent"] in names]
    else:
        variant_keys = list(TIER5_VARIANTS.keys())

    if not variant_keys:
        print("No evo turret variants to generate.")
        return

    total = len(variant_keys)
    print(f"\n=== EVO TURRETS ({total} variants x 16 directions = {total * 16} sprites) ===\n")

    # Phase A: Generate all evo turret idle references in parallel
    print("Phase A: Generating evo turret references (SE)...")
    ref_tasks = [
        (key, _gen_evo_turret_ref, (client, key, TIER5_VARIANTS[key]), {})
        for key in variant_keys
    ]
    ref_results = run_parallel(ref_tasks)

    # Collect idle refs for fire pose init_image
    idle_ref_map: dict[str, bytes] = {}

    # Phase B: Generate 8-direction idle rotations in parallel
    print("\nPhase B: Generating 8-direction idle rotations...")
    rot_tasks = []
    for result in ref_results:
        if result is None:
            continue
        variant_key, turret_ref = result
        if not turret_ref:
            print(f"  ERROR: No evo turret reference for {variant_key}, skipping rotations")
            continue
        idle_ref_map[variant_key] = turret_ref
        variant = TIER5_VARIANTS[variant_key]
        parent_name = variant["parent"]
        path_letter = variant_key.split("_")[-1][0]
        prefix = f"tier5{path_letter}_turret"
        rot_tasks.append(
            (variant_key, _gen_turret_rotations,
             (client, parent_name, turret_ref, prefix, False), {})
        )
    if rot_tasks:
        run_parallel(rot_tasks)

    # Phase C: Generate fire pose references using idle refs as init_image
    print(f"\nPhase C: Generating evo fire pose references ({len(idle_ref_map)} variants)...")
    fire_ref_tasks = [
        (key, _gen_evo_fire_ref,
         (client, key, TIER5_VARIANTS[key], idle_ref_map.get(key)), {})
        for key in variant_keys if key in idle_ref_map
    ]
    fire_ref_results = run_parallel(fire_ref_tasks)

    # Phase D: Generate 8-direction fire rotations
    print("\nPhase D: Generating 8-direction fire rotations...")
    fire_rot_tasks = []
    for result in fire_ref_results:
        if result is None:
            continue
        variant_key, fire_ref = result
        if not fire_ref:
            print(f"  ERROR: No fire pose reference for {variant_key}, skipping")
            continue
        variant = TIER5_VARIANTS[variant_key]
        parent_name = variant["parent"]
        path_letter = variant_key.split("_")[-1][0]
        prefix = f"tier5{path_letter}_turret_fire"
        fire_rot_tasks.append(
            (variant_key, _gen_turret_rotations,
             (client, parent_name, fire_ref, prefix, False), {})
        )
    if fire_rot_tasks:
        run_parallel(fire_rot_tasks)


def _gen_evo_turret_ref_rd(rd_client: RetroDiffusionClient, variant_key: str,
                            variant: dict) -> tuple[str, bytes]:
    """Generate evo turret SE reference via Retro Diffusion.

    Uses the parent tower's base sprite as style reference.
    Returns (variant_key, image_bytes).
    """
    parent_name = variant["parent"]
    parent = TOWERS[parent_name]
    path_letter = variant_key.split("_")[-1][0]
    print(f"  [RD] Generating evo turret reference for {variant_key} ({variant['name']}, SE)...")

    prompt = build_evo_turret_prompt(variant, parent, path_letter)

    # Use parent's base sprite as style reference
    base_path = SPRITES_DIR / "towers" / parent_name / "base.png"
    ref_imgs = None
    if base_path.exists():
        with open(base_path, "rb") as f:
            img_data = f.read()
        # RD needs RGB, no alpha
        pil_img = Image.open(io.BytesIO(img_data)).convert("RGB")
        buf = io.BytesIO()
        pil_img.save(buf, format="PNG")
        ref_imgs = [base64.b64encode(buf.getvalue()).decode()]
        print(f"    Using parent base sprite as RD style reference")

    images = rd_client.generate(
        prompt, 64, 64,
        style="rd_pro__isometric",
        reference_images=ref_imgs,
        remove_bg=True,
    )
    img = images[0] if images else b""
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{parent_name}/tier5{path_letter}_turret_ref.png", open_viewer=False)
    return (variant_key, img)


def gen_evo_turrets_rd(rd_client: RetroDiffusionClient, pl_client: PixelLabClient,
                        names: list[str] | None = None,
                        variants_filter: list[str] | None = None):
    """Generate tier 5 evo turrets: RD for SE reference, PixelLab for 8-rotations.

    Args:
        names: filter by parent tower names
        variants_filter: filter by specific variant keys
    """
    # Determine which variants to generate
    if variants_filter:
        variant_keys = [k for k in variants_filter if k in TIER5_VARIANTS]
        for k in variants_filter:
            if k not in TIER5_VARIANTS:
                print(f"  WARNING: Unknown variant '{k}', skipping. "
                      f"Available: {', '.join(TIER5_VARIANTS.keys())}")
    elif names:
        variant_keys = [k for k, v in TIER5_VARIANTS.items() if v["parent"] in names]
    else:
        variant_keys = list(TIER5_VARIANTS.keys())

    if not variant_keys:
        print("No evo turret variants to generate.")
        return

    total = len(variant_keys)
    print(f"\n=== EVO TURRETS via Retro Diffusion ({total} variants) ===\n")

    # Phase A: Generate all evo turret refs via RD
    print("Phase A: Generating evo turret references via RD...")
    ref_tasks = [
        (key, _gen_evo_turret_ref_rd, (rd_client, key, TIER5_VARIANTS[key]), {})
        for key in variant_keys
    ]
    ref_results = run_parallel(ref_tasks)

    # Collect idle refs for fire pose init_image
    idle_ref_map: dict[str, bytes] = {}

    # Phase B: Generate 8-direction idle rotations via PixelLab
    print("\nPhase B: Generating 8-direction idle rotations via PixelLab...")
    rot_tasks = []
    for result in ref_results:
        if result is None:
            continue
        variant_key, turret_ref = result
        if not turret_ref:
            print(f"  ERROR: No evo turret reference for {variant_key}, skipping rotations")
            continue
        idle_ref_map[variant_key] = turret_ref
        variant = TIER5_VARIANTS[variant_key]
        parent_name = variant["parent"]
        path_letter = variant_key.split("_")[-1][0]
        prefix = f"tier5{path_letter}_turret"
        rot_tasks.append(
            (variant_key, _gen_turret_rotations,
             (pl_client, parent_name, turret_ref, prefix, False), {})
        )
    if rot_tasks:
        run_parallel(rot_tasks)

    # Phase C: Generate fire pose references via PixelLab (using idle refs as init)
    print(f"\nPhase C: Generating evo fire pose references ({len(idle_ref_map)} variants)...")
    fire_ref_tasks = [
        (key, _gen_evo_fire_ref,
         (pl_client, key, TIER5_VARIANTS[key], idle_ref_map.get(key)), {})
        for key in variant_keys if key in idle_ref_map
    ]
    fire_ref_results = run_parallel(fire_ref_tasks)

    # Phase D: Generate 8-direction fire rotations via PixelLab
    print("\nPhase D: Generating 8-direction fire rotations via PixelLab...")
    fire_rot_tasks = []
    for result in fire_ref_results:
        if result is None:
            continue
        variant_key, fire_ref = result
        if not fire_ref:
            print(f"  ERROR: No fire pose reference for {variant_key}, skipping")
            continue
        variant = TIER5_VARIANTS[variant_key]
        parent_name = variant["parent"]
        path_letter = variant_key.split("_")[-1][0]
        prefix = f"tier5{path_letter}_turret_fire"
        fire_rot_tasks.append(
            (variant_key, _gen_turret_rotations,
             (pl_client, parent_name, fire_ref, prefix, False), {})
        )
    if fire_rot_tasks:
        run_parallel(fire_rot_tasks)


def _gen_single_base(client: PixelLabClient, name: str, info: dict) -> None:
    """Generate a single tower base platform."""
    if info.get("skip_base"):
        print(f"  Emitting transparent base for {name} (skip_base)...")
        buf = io.BytesIO()
        Image.new("RGBA", (64, 64), (0, 0, 0, 0)).save(buf, format="PNG")
        save_image(buf.getvalue(), f"towers/{name}/base.png")
        return
    print(f"  Generating base_{name}...")
    img = client.generate_image(
        build_base_prompt(info),
        64, 64,
        isometric=True,
        negative_description=BASE_NEGATIVE,
    )
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{name}/base.png")


def gen_bases(client: PixelLabClient, names: list[str] | None = None):
    """Phase: Generate tower base platforms."""
    tower_names = names or list(TOWERS.keys())
    total = len(tower_names)
    print(f"\n=== TOWER BASES ({total} bases) ===\n")

    tasks = [
        (name, _gen_single_base, (client, name, TOWERS[name]), {})
        for name in tower_names
    ]
    run_parallel(tasks)


def _gen_single_enemy_char(client: PixelLabClient, name: str, info: dict) -> tuple[str, str]:
    """Create a single enemy character. Returns (name, char_id)."""
    w, h = info["size"]
    print(f"  Creating character: {name}...")
    try:
        char_id, dir_images = client.create_character_8dir(
            f"{CHAR_PROMPT}, {info['desc']}",
            w, h,
            isometric=True,
        )
        print(f"  Character ID for {name}: {char_id}")
        for dir_name, img_data in dir_images:
            save_image(
                img_data,
                f"enemies/{name}/walk_{dir_name}_01.png",
                open_viewer=False,
            )
        print(f"  Saved {len(dir_images)} directional sprites for {name}")
        return (name, char_id)
    except Exception as e:
        print(f"  ERROR creating character {name}: {e}")
        print(f"  Falling back to single SE sprite for {name}...")
        img = client.generate_image(
            f"{CHAR_PROMPT}, single character {CHROMA_BG}, "
            f"facing south-east, walking pose, {info['desc']}",
            w, h, isometric=True,
            negative_description=NEGATIVE,
        )
        if img:
            img = remove_background(img)
        save_image(img, f"enemies/{name}/walk_se_01.png")
        return (name, "")


def gen_enemy_characters(client: PixelLabClient, names: list[str] | None = None):
    """Phase: Create persistent enemy characters with 8 directional views."""
    enemy_names = names or list(ENEMIES.keys())
    total = len(enemy_names)
    manifest = load_manifest()
    print(f"\n=== ENEMY CHARACTERS ({total} characters x 8 directions) ===\n")

    # Filter out already-created characters
    to_create = []
    for name in enemy_names:
        if name in manifest and manifest[name]:
            print(f"  {name}: already created (char_id={manifest[name]}), skipping")
        else:
            to_create.append(name)

    if not to_create:
        print("  All characters already exist in manifest.")
        return

    tasks = [
        (name, _gen_single_enemy_char, (client, name, ENEMIES[name]), {})
        for name in to_create
    ]
    results = run_parallel(tasks)

    # Update manifest with all new character IDs
    for result in results:
        if result is not None:
            name, char_id = result
            if char_id:
                manifest[name] = char_id
    save_manifest(manifest)


def _gen_single_enemy_anim(client: PixelLabClient, name: str, char_id: str) -> None:
    """Animate a single enemy character's walk cycle."""
    print(f"  Animating walk cycle for {name} (char_id={char_id})...")
    try:
        anim_frames = client.animate_character(
            char_id,
            template_animation_id="walking-4-frames",
            directions=None,  # All 8 directions
        )
        for dir_name, frames in anim_frames.items():
            for frame_idx, frame_data in enumerate(frames, 1):
                save_image(
                    frame_data,
                    f"enemies/{name}/walk_{dir_name}_{frame_idx:02d}.png",
                    open_viewer=False,
                )
        total_frames = sum(len(f) for f in anim_frames.values())
        print(f"  Saved {total_frames} animation frames for {name} across {len(anim_frames)} directions")
    except Exception as e:
        print(f"  ERROR animating {name}: {e}")


def gen_enemy_animations(client: PixelLabClient, names: list[str] | None = None):
    """Phase: Generate walk cycle animations for existing characters."""
    enemy_names = names or list(ENEMIES.keys())
    manifest = load_manifest()
    total = len(enemy_names)
    print(f"\n=== ENEMY WALK ANIMATIONS ({total} characters) ===\n")

    tasks = []
    for name in enemy_names:
        char_id = manifest.get(name)
        if not char_id:
            print(f"  {name}: no character_id in manifest, skipping (run enemy-chars first)")
            continue
        tasks.append(
            (name, _gen_single_enemy_anim, (client, name, char_id), {})
        )

    if tasks:
        run_parallel(tasks)


def _gen_single_projectile(client: PixelLabClient, name: str, desc: str, size: int) -> None:
    """Generate a single projectile sprite."""
    print(f"  Generating proj_{name}...")
    api_size = max(size, 32)
    img = client.generate_image(
        f"{SPRITE_PROMPT}, game projectile sprite, small, motion blur suggestion, {desc}",
        api_size, api_size,
        negative_description=NEGATIVE,
    )
    if img:
        img = remove_background(img)
    save_image(img, f"projectiles/proj_{name}.png")


def gen_projectiles(client: PixelLabClient):
    """Generate all projectile sprites."""
    print(f"\n=== PROJECTILES ({len(PROJECTILES)}) ===\n")
    tasks = [
        (name, _gen_single_projectile, (client, name, desc, size), {})
        for name, (desc, size) in PROJECTILES.items()
    ]
    run_parallel(tasks)


def _gen_single_effect(client: PixelLabClient, name: str, desc: str, size: int) -> None:
    """Generate a single effect sprite."""
    print(f"  Generating effect_{name}...")
    img = client.generate_image(
        f"{SPRITE_PROMPT}, game effect sprite, animation frame, {desc}",
        max(size, 32), max(size, 32),
        negative_description=NEGATIVE,
    )
    if img:
        img = remove_background(img)
    save_image(img, f"effects/effect_{name}_01.png")


def gen_effects(client: PixelLabClient):
    """Generate all effect sprites."""
    print(f"\n=== EFFECTS ({len(EFFECTS)}) ===\n")
    tasks = [
        (name, _gen_single_effect, (client, name, desc, size), {})
        for name, (desc, size) in EFFECTS.items()
    ]
    run_parallel(tasks)


def _gen_single_building(client: PixelLabClient, name: str, info: dict) -> None:
    """Generate a single city building sprite."""
    w, h = info["size"]
    print(f"  Generating building_{name}...")
    img = client.generate_map_object(
        f"{SCENE_PROMPT}, building sprite, {info['desc']}",
        w, h,
        view="high top-down",
    )
    if img:
        img = remove_background(img)
        # Mute buildings: desaturate + flatten contrast so they don't compete with gameplay
        from PIL import Image as PILImage, ImageEnhance
        import numpy as np
        pil = PILImage.open(io.BytesIO(img)).convert("RGBA")
        # Desaturate 60%
        r, g, b, a = pil.split()
        rgb = PILImage.merge("RGB", (r, g, b))
        rgb = ImageEnhance.Color(rgb).enhance(0.4)
        dr, dg, db = rgb.split()
        pil = PILImage.merge("RGBA", (dr, dg, db, a))
        # Flatten contrast 50% toward mean
        arr = np.array(pil, dtype=np.float32)
        rgb_arr = arr[:, :, :3]
        alpha_arr = arr[:, :, 3]
        mask = alpha_arr > 0
        if mask.any():
            mean_rgb = rgb_arr[mask].mean(axis=0)
            rgb_arr[mask] = rgb_arr[mask] * 0.5 + mean_rgb * 0.5
        arr[:, :, :3] = np.clip(rgb_arr, 0, 255)
        pil = PILImage.fromarray(arr.astype(np.uint8), "RGBA")
        buf = io.BytesIO()
        pil.save(buf, format="PNG")
        img = buf.getvalue()
    save_image(img, f"buildings/building_{name}.png")


def gen_city(client: PixelLabClient):
    """Generate city background building sprites."""
    total = len(BUILDINGS)
    print(f"\n=== CITY BUILDINGS ({total}) ===\n")
    tasks = [
        (name, _gen_single_building, (client, name, info), {})
        for name, info in BUILDINGS.items()
    ]
    run_parallel(tasks)


def _gen_single_animated_detail(client: PixelLabClient, name: str, info: dict) -> None:
    """Generate a single animated detail: reference frame then animation."""
    w, h = info["size"]
    num_frames = info["frames"]
    print(f"  Generating anim_{name} ({num_frames} frames)...")

    # First generate a reference frame
    ref_img = client.generate_image(
        f"{SPRITE_PROMPT}, {info['desc']}, still reference frame",
        w, h,
        negative_description=NEGATIVE,
    )
    if not ref_img:
        print(f"  ERROR: No reference image for {name}")
        return

    ref_img = remove_background(ref_img)
    save_image(ref_img, f"animated/anim_{name}_01.png", open_viewer=False)

    # Then animate it
    try:
        frames = client.animate_with_text(
            img_to_b64(ref_img),
            info["desc"],
            w, h,
            num_frames=num_frames,
            version=2,
        )
        for frame_idx, frame_data in enumerate(frames, 1):
            save_image(
                frame_data,
                f"animated/anim_{name}_{frame_idx:02d}.png",
                open_viewer=False,
            )
        print(f"  Saved {len(frames)} frames for {name}")
    except Exception as e:
        print(f"  ERROR animating {name}: {e}")


def gen_animated_details(client: PixelLabClient):
    """Generate animated detail sprites (burning barrel, waving flag, etc.)."""
    total = len(ANIMATED_DETAILS)
    print(f"\n=== ANIMATED DETAILS ({total}) ===\n")
    # Each detail has internal dependency (ref → animate), but different details
    # are independent of each other, so parallelize across items.
    tasks = [
        (name, _gen_single_animated_detail, (client, name, info), {})
        for name, info in ANIMATED_DETAILS.items()
    ]
    run_parallel(tasks)


def _gen_single_tile(client: PixelLabClient, name: str, desc: str) -> None:
    """Generate a 32x32 isometric tile, crop to content, resize to 64x32."""
    from PIL import Image as PILImage
    import io

    print(f"  Generating tile_{name}...")
    tile_prompt = (
        f"{STYLE}, flat isometric floor tile, top-down surface texture only, "
        f"no height no depth no 3D objects, seamless tiling edges, {desc}"
    )
    img_bytes = client.generate_isometric_tile(
        tile_prompt, size=32, shape="thin tile",
    )
    # Crop to content bbox, then resize to exactly 64x32 to fill the atlas slot
    pil_img = PILImage.open(io.BytesIO(img_bytes)).convert("RGBA")
    bbox = pil_img.getbbox()
    if bbox:
        content = pil_img.crop(bbox)
    else:
        content = pil_img
    result = content.resize((64, 32), PILImage.NEAREST)
    # Flatten contrast: blend each pixel 80% toward the tile's average color
    import numpy as np
    arr = np.array(result, dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3:4]
    mask = alpha > 0
    if mask.any():
        mean_rgb = rgb[mask[:, :, 0]].mean(axis=0)
        rgb = rgb * 0.2 + mean_rgb * 0.8
    arr[:, :, :3] = np.clip(rgb, 0, 255)
    result = PILImage.fromarray(arr.astype(np.uint8), "RGBA")
    buf = io.BytesIO()
    result.save(buf, format="PNG")
    save_image(buf.getvalue(), f"tiles/tile_{name}.png")


def gen_tiles(client: PixelLabClient):
    """Generate all isometric tiles."""
    print(f"\n=== TILES ({len(TILES)}) ===\n")
    tasks = [
        (name, _gen_single_tile, (client, name, desc), {})
        for name, desc in TILES.items()
    ]
    run_parallel(tasks)


def _gen_single_tileset(client: PixelLabClient, name: str, desc: str) -> None:
    """Generate a single Wang-style tileset."""
    print(f"  Generating tileset_{name}...")
    try:
        tiles = client.create_tileset(
            f"{SCENE_PROMPT}, tileset transition, {desc}",
            tile_size=32,
        )
        for tile_idx, tile_data in enumerate(tiles):
            save_image(
                tile_data,
                f"tiles/tileset_{name}_{tile_idx:02d}.png",
                open_viewer=False,
            )
        print(f"  Generated {len(tiles)} tiles for {name}")
    except Exception as e:
        print(f"  ERROR generating tileset {name}: {e}")


def gen_tilesets(client: PixelLabClient):
    """Generate Wang-style tilesets."""
    tilesets = {
        "ground_path": "urban asphalt transitioning to warning-stripe marked path, "
                       "cracked concrete to yellow hazard paint stripes, night scene",
        "ground_wall": "urban asphalt transitioning to concrete barrier wall, "
                       "flat ground to raised brutalist wall, night scene",
        "ground_rubble": "urban asphalt transitioning to destroyed rubble debris, "
                         "clean road to collapsed concrete chunks and rebar, night scene",
    }
    total = len(tilesets)
    print(f"\n=== TILESETS ({total} Wang tilesets) ===\n")
    tasks = [
        (name, _gen_single_tileset, (client, name, desc), {})
        for name, desc in tilesets.items()
    ]
    run_parallel(tasks)


def _gen_single_boss(client: PixelLabClient, name: str, info: dict) -> None:
    """Generate a single boss enemy sprite."""
    print(f"  Generating boss_{name}_idle...")
    img = client.generate_image(
        f"{CHAR_PROMPT}, boss character, imposing large figure, "
        f"detailed for size, single game sprite {CHROMA_BG}, {info['desc']}",
        48, 48, isometric=True,
        negative_description=NEGATIVE,
    )
    save_image(img, f"bosses/boss_{name}_idle.png")


def gen_bosses(client: PixelLabClient):
    """Generate boss enemy sprites."""
    print(f"\n=== BOSS ENEMIES ({len(BOSSES)}) ===\n")
    tasks = [
        (name, _gen_single_boss, (client, name, info), {})
        for name, info in BOSSES.items()
    ]
    run_parallel(tasks)


def _gen_single_prop(client: PixelLabClient, name: str, desc: str, w: int, h: int) -> None:
    """Generate a single environment prop."""
    print(f"  Generating prop_{name}...")
    api_w = max(w, 32)
    api_h = max(h, 32)
    img = client.generate_map_object(
        f"{SPRITE_PROMPT}, environment prop, urban debris, {desc}",
        api_w, api_h,
        view="low top-down",
    )
    save_image(img, f"props/prop_{name}.png")


def gen_props(client: PixelLabClient):
    """Generate environment props."""
    print(f"\n=== ENVIRONMENT PROPS ({len(PROPS)}) ===\n")
    tasks = [
        (name, _gen_single_prop, (client, name, desc, w, h), {})
        for name, (desc, w, h) in PROPS.items()
    ]
    run_parallel(tasks)


def _gen_single_ui_icon(client: PixelLabClient, name: str, desc: str) -> None:
    """Generate a single UI icon."""
    print(f"  Generating icon_{name}...")
    img = client.generate_image(
        f"{UI_PROMPT}, {desc}",
        32, 32,
    )
    save_image(img, f"ui/icon_{name}.png")


def gen_ui(client: PixelLabClient):
    """Generate UI icons."""
    print(f"\n=== UI ICONS ({len(UI_ICONS)}) ===\n")
    tasks = [
        (name, _gen_single_ui_icon, (client, name, desc), {})
        for name, desc in UI_ICONS.items()
    ]
    run_parallel(tasks)


# ---------------------------------------------------------------------------
# Retro Diffusion Tower Generation (style-matched base + turret)
# ---------------------------------------------------------------------------

def _gen_tower_base_rd(rd_client: RetroDiffusionClient, name: str, info: dict) -> tuple[str, bytes]:
    """Generate tower base via Retro Diffusion. Returns (name, image_bytes)."""
    if info.get("skip_base"):
        print(f"  [RD] Emitting transparent base for {name} (skip_base)...")
        buf = io.BytesIO()
        Image.new("RGBA", (64, 64), (0, 0, 0, 0)).save(buf, format="PNG")
        img = buf.getvalue()
        save_image(img, f"towers/{name}/base.png", open_viewer=False)
        return (name, img)
    print(f"  [RD] Generating base for {name}...")
    prompt = build_base_prompt(info)
    images = rd_client.generate(prompt, 64, 64, style="rd_pro__isometric", remove_bg=True)
    img = images[0] if images else b""
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{name}/base.png", open_viewer=False)
    return (name, img)


def _gen_turret_with_base_ref_rd(rd_client: RetroDiffusionClient, name: str, info: dict,
                                  base_b64: str) -> tuple[str, bytes]:
    """Generate turret SE reference via RD, using the base sprite as style reference.

    Returns (name, turret_image_bytes).
    """
    cop_prompt = info.get("cop_prompt")
    if cop_prompt:
        print(f"  [RD] Generating cop figure reference for {name} (no base reference)...")
        prompt = cop_prompt
        ref_imgs = None
    else:
        print(f"  [RD] Generating turret reference for {name} (with base as reference)...")
        prompt = build_turret_prompt(info)
        ref_imgs = [base_b64] if base_b64 else None
    images = rd_client.generate(
        prompt, 64, 64,
        style="rd_pro__isometric",
        reference_images=ref_imgs,
        remove_bg=True,
    )
    img = images[0] if images else b""
    if img:
        img = remove_background(img)
    save_image(img, f"towers/{name}/turret_ref.png", open_viewer=False)
    return (name, img)


def _gen_turret_rotations_rd(pl_client: PixelLabClient, name: str, turret_ref: bytes) -> None:
    """Generate 8 turret rotations using PixelLab's proven rotate_8_directions.

    Uses PL for rotation even in RD pipeline because:
    - PL rotate_8_directions works at 64x64 (RD's animation__8_dir_rotation is 80x80)
    - PL rotation quality is proven for this project
    """
    _gen_turret_rotations(pl_client, name, turret_ref)


def gen_towers_rd(rd_client: RetroDiffusionClient, pl_client: PixelLabClient,
                  names: list[str] | None = None):
    """Generate towers using Retro Diffusion for base+turret, PixelLab for rotations.

    Pipeline:
      Phase A: Generate all tower bases via RD (parallel)
      Phase B: Generate all turret refs via RD with base as reference (parallel)
      Phase C: Generate 8-rotations via PixelLab (parallel)
    """
    tower_names = names or list(TOWERS.keys())
    total = len(tower_names)
    print(f"\n=== TOWERS via Retro Diffusion ({total} towers) ===\n")

    # Phase A: Generate all bases in parallel
    print("Phase A: Generating tower bases via RD...")
    base_tasks = [
        (name, _gen_tower_base_rd, (rd_client, name, TOWERS[name]), {})
        for name in tower_names
    ]
    base_results = run_parallel(base_tasks)

    # Collect base images for reference in turret generation
    base_map: dict[str, bytes] = {}
    for result in base_results:
        if result is not None:
            name, img = result
            if img:
                base_map[name] = img

    # Phase B: Generate turret refs with base as style reference
    print("\nPhase B: Generating turret references via RD (with base as reference)...")
    turret_tasks = []
    for name in tower_names:
        base_img = base_map.get(name)
        if not base_img:
            print(f"  WARNING: No base image for {name}, generating turret without reference")
            turret_tasks.append(
                (name, _gen_turret_with_base_ref_rd,
                 (rd_client, name, TOWERS[name], ""), {})
            )
        else:
            turret_tasks.append(
                (name, _gen_turret_with_base_ref_rd,
                 (rd_client, name, TOWERS[name], img_to_b64(base_img)), {})
            )
    turret_results = run_parallel(turret_tasks)

    # Phase C: Generate 8-direction rotations via PixelLab
    print("\nPhase C: Generating 8-direction rotations via PixelLab...")
    rot_tasks = []
    for result in turret_results:
        if result is None:
            continue
        name, turret_ref = result
        if not turret_ref:
            print(f"  ERROR: No turret reference for {name}, skipping rotations")
            continue
        rot_tasks.append(
            (name, _gen_turret_rotations_rd, (pl_client, name, turret_ref), {})
        )
    if rot_tasks:
        run_parallel(rot_tasks)

    # Collect idle turret refs for fire pose init_image
    turret_ref_map: dict[str, bytes] = {}
    for result in turret_results:
        if result is not None:
            name, img = result
            if img:
                turret_ref_map[name] = img

    # Phase D/E: Fire pose refs + rotations for towers with cop_fire_prompt
    fire_names = [n for n in tower_names if TOWERS[n].get("cop_fire_prompt")]
    if fire_names:
        print(f"\nPhase D: Generating fire pose references ({len(fire_names)} towers)...")
        fire_ref_tasks = [
            (name, _gen_fire_ref, (pl_client, name, TOWERS[name], turret_ref_map.get(name)), {})
            for name in fire_names
        ]
        fire_ref_results = run_parallel(fire_ref_tasks)

        print("\nPhase E: Generating fire pose 8-direction rotations...")
        fire_rot_tasks = []
        for result in fire_ref_results:
            if result is None:
                continue
            name, fire_ref = result
            if not fire_ref:
                continue
            fire_rot_tasks.append(
                (name, _gen_turret_rotations, (pl_client, name, fire_ref, "turret_fire", True), {})
            )
        if fire_rot_tasks:
            run_parallel(fire_rot_tasks)


def gen_test_foundation(client: PixelLabClient):
    """Test the pipeline with 1 tower + 1 enemy before full generation."""
    print("\n=== FOUNDATION TEST (1 tower + 1 enemy) ===\n")

    # Test 1: One turret + base
    print("--- Test: rubber_bullet turret ---")
    gen_turrets(client, names=["rubber_bullet"])
    gen_bases(client, names=["rubber_bullet"])

    # Test 2: One enemy character + walk cycle
    print("\n--- Test: rioter enemy ---")
    gen_enemy_characters(client, names=["rioter"])
    gen_enemy_animations(client, names=["rioter"])

    print("\n=== FOUNDATION TEST COMPLETE ===")
    print("Review the generated sprites before running full phases.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _load_env_key(var_name: str) -> str | None:
    """Load a key from environment or .env file. Returns None if not found."""
    key = os.environ.get(var_name)
    if key:
        return key
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith(f"{var_name}="):
                return line.split("=", 1)[1].strip()
    return None


def load_api_key() -> str:
    key = _load_env_key("PIXELLAB_API_KEY")
    if key:
        return key
    print("ERROR: PIXELLAB_API_KEY not found. Set it in .env or as environment variable.")
    sys.exit(1)


def load_rd_api_key(required: bool = False) -> str | None:
    """Load Retro Diffusion API key. Required when --backend is retrodiffusion."""
    key = _load_env_key("RD_API_KEY")
    if not key and required:
        print("ERROR: RD_API_KEY not found. Set it in .env or as environment variable.")
        print("  Sign up at https://retrodiffusion.ai and add RD_API_KEY=... to .env")
        sys.exit(1)
    return key


def _is_tower_phase(phase: str) -> bool:
    """Check if a phase involves tower generation."""
    return phase in ("turrets", "bases", "evo-turrets")


def main():
    parser = argparse.ArgumentParser(
        description="Generate Goligee pixel art assets via PixelLab and/or Retro Diffusion API"
    )
    parser.add_argument("--phase", choices=[
        "turrets", "bases", "evo-turrets", "enemy-chars", "enemy-anims",
        "projectiles", "effects", "city", "animated",
        "tiles", "tilesets", "ui", "props", "bosses", "all",
    ], help="Which phase/category to generate")
    parser.add_argument("--backend", choices=["pixellab", "retrodiffusion", "auto"],
                        default="auto",
                        help="Backend for tower generation: pixellab, retrodiffusion, or auto "
                             "(default: auto = RD for towers, PixelLab for everything else)")
    parser.add_argument("--towers", type=str, default=None,
                        help="Comma-separated tower names to generate (e.g. rubber_bullet,tear_gas)")
    parser.add_argument("--enemies", type=str, default=None,
                        help="Comma-separated enemy names to generate (e.g. rioter,drummer)")
    parser.add_argument("--variants", type=str, default=None,
                        help="Comma-separated evo variant keys (e.g. rubber_bullet_a5,tear_gas_b5)")
    parser.add_argument("--test-foundation", action="store_true",
                        help="Test pipeline with 1 tower + 1 enemy")
    parser.add_argument("--single", type=str, help="Generate a single asset by name")
    parser.add_argument("--seed", type=int, default=None, help="Global seed for reproducibility")
    args = parser.parse_args()

    if not args.phase and not args.single and not args.test_foundation:
        parser.print_help()
        sys.exit(0)

    # Parse tower name filter
    tower_filter = None
    if args.towers:
        tower_filter = [t.strip() for t in args.towers.split(",")]
        for t in tower_filter:
            if t not in TOWERS:
                print(f"ERROR: Unknown tower '{t}'. Available: {', '.join(TOWERS.keys())}")
                sys.exit(1)

    # Parse enemy name filter
    enemy_filter = None
    if args.enemies:
        enemy_filter = [e.strip() for e in args.enemies.split(",")]
        for e in enemy_filter:
            if e not in ENEMIES:
                print(f"ERROR: Unknown enemy '{e}'. Available: {', '.join(ENEMIES.keys())}")
                sys.exit(1)

    # Parse variant filter
    variant_filter = None
    if args.variants:
        variant_filter = [v.strip() for v in args.variants.split(",")]
        for v in variant_filter:
            if v not in TIER5_VARIANTS:
                print(f"ERROR: Unknown variant '{v}'. Available: {', '.join(TIER5_VARIANTS.keys())}")
                sys.exit(1)

    # Determine which backends are needed
    backend = args.backend
    use_rd = backend in ("retrodiffusion", "auto")
    phase = args.phase or ""

    # Always need PixelLab (for non-tower phases and for turret rotations)
    api_key = load_api_key()
    pl_client = PixelLabClient(api_key)

    # Initialize RD client if needed
    rd_client = None
    if use_rd:
        rd_key = load_rd_api_key(required=(backend == "retrodiffusion"))
        if rd_key:
            rd_client = RetroDiffusionClient(rd_key)
        elif backend == "auto":
            print("INFO: RD_API_KEY not found, falling back to PixelLab for towers")
            use_rd = False

    # Check balances
    try:
        balance = pl_client._get("balance")
        print(f"PixelLab balance: {json.dumps(balance, indent=2)}")
    except Exception as e:
        print(f"Could not check PixelLab balance: {e}")

    if rd_client:
        try:
            credits = rd_client.check_credits()
            print(f"Retro Diffusion credits: {credits}")
        except Exception as e:
            print(f"Could not check RD credits: {e}")

    # Helper: run tower generation with the appropriate backend
    def run_towers(names: list[str] | None = None):
        """Generate towers using the selected backend."""
        target_names = names or tower_filter
        if use_rd and rd_client:
            gen_towers_rd(rd_client, pl_client, names=target_names)
        else:
            gen_turrets(pl_client, names=target_names)
            gen_bases(pl_client, names=target_names)

    def run_evo_turrets():
        """Generate evo turrets using the selected backend."""
        if use_rd and rd_client:
            gen_evo_turrets_rd(rd_client, pl_client,
                               names=tower_filter, variants_filter=variant_filter)
        else:
            gen_evo_turrets(pl_client,
                            names=tower_filter, variants_filter=variant_filter)

    if args.test_foundation:
        gen_test_foundation(pl_client)
    elif phase == "all":
        run_towers()
        run_evo_turrets()
        gen_enemy_characters(pl_client)
        gen_enemy_animations(pl_client)
        gen_projectiles(pl_client)
        gen_effects(pl_client)
        gen_city(pl_client)
        gen_animated_details(pl_client)
        gen_tiles(pl_client)
        gen_tilesets(pl_client)
        gen_bosses(pl_client)
        gen_props(pl_client)
        gen_ui(pl_client)
    elif phase:
        if phase == "evo-turrets":
            run_evo_turrets()
        elif _is_tower_phase(phase):
            run_towers()
        else:
            phase_map = {
                "enemy-chars": lambda: gen_enemy_characters(pl_client, names=enemy_filter),
                "enemy-anims": lambda: gen_enemy_animations(pl_client, names=enemy_filter),
                "projectiles": lambda: gen_projectiles(pl_client),
                "effects": lambda: gen_effects(pl_client),
                "city": lambda: gen_city(pl_client),
                "animated": lambda: gen_animated_details(pl_client),
                "tiles": lambda: gen_tiles(pl_client),
                "tilesets": lambda: gen_tilesets(pl_client),
                "ui": lambda: gen_ui(pl_client),
                "props": lambda: gen_props(pl_client),
                "bosses": lambda: gen_bosses(pl_client),
            }
            phase_map[phase]()
    elif args.single:
        name = args.single.lower()
        if name in TOWERS:
            run_towers(names=[name])
        elif name in ENEMIES:
            gen_enemy_characters(pl_client, names=[name])
            gen_enemy_animations(pl_client, names=[name])
        elif name in BOSSES:
            gen_bosses(pl_client)  # TODO: single boss
        elif name in PROJECTILES:
            gen_projectiles(pl_client)  # TODO: single projectile
        elif name in EFFECTS:
            gen_effects(pl_client)  # TODO: single effect
        else:
            print(f"Asset '{name}' not found.")
            sys.exit(1)

    print("\nDone generating! Running asset sync...")
    import subprocess
    subprocess.run(
        [sys.executable, str(Path(__file__).parent / "sync_assets.py")],
        cwd=str(PROJECT_ROOT),
    )


if __name__ == "__main__":
    main()
