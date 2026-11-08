#!/usr/bin/env python3
"""Thumbnails made by GNOME's own thumbnail factory, as Files makes them.

  gnome_thumbnail.py OUT MODEL...

Files (Nautilus), the GNOME desktop's other file choosers and anything else
built on libgnome-desktop ask GnomeDesktopThumbnailFactory for a picture of
a file: it reads the thumbnailer entries in each XDG_DATA_DIRS'
thumbnailers/, finds the one for the file's MIME type (GIO's, from the
shared MIME database), runs its Exec in bubblewrap through PATH, and loads
the PNG it leaves. This does the same at the large size Files asks for (256
px), saves what the factory made as OUT/<file name>.png, and prints a JSON
line for each: its MIME type, whether a thumbnailer takes it, the size made,
the milliseconds from asking to the picture, or the factory's error.

Run with the environment a desktop would have: XDG_DATA_DIRS and PATH with
the package's share/ and bin/ in them.
"""

import json
import sys
import time
from pathlib import Path

import gi

gi.require_version("GnomeDesktop", "4.0")
gi.require_version("Gio", "2.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib, GnomeDesktop  # noqa: E402


def filled(picture: GdkPixbuf.Pixbuf) -> float:
    """The share of the picture that is not see-through: the model, where
    the ground is clear."""
    if not picture.get_has_alpha():
        return 1.0
    width, height = picture.get_width(), picture.get_height()
    stride, step = picture.get_rowstride(), picture.get_n_channels()
    data = picture.get_pixels()
    solid = sum(1 for y in range(height) for x in range(width)
                if data[y * stride + x * step + 3] >= 128)
    return round(solid / float(width * height), 4)


def main(argv: list[str]) -> int:
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    factory = GnomeDesktop.DesktopThumbnailFactory.new(GnomeDesktop.DesktopThumbnailSize.LARGE)
    for name in argv[1:]:
        model = Path(name).resolve()
        file = Gio.File.new_for_path(str(model))
        info = file.query_info("standard::content-type,time::modified", Gio.FileQueryInfoFlags.NONE)
        mime = info.get_content_type()
        uri = file.get_uri()
        said = {"file": str(model), "mime": mime,
                "taken": bool(factory.can_thumbnail(uri, mime, info.get_attribute_uint64(
                    "time::modified")))}
        began = time.monotonic()
        try:
            picture: GdkPixbuf.Pixbuf = factory.generate_thumbnail(uri, mime, None)
            said["ms"] = round((time.monotonic() - began) * 1000)
            said["size"] = [picture.get_width(), picture.get_height()]
            said["alpha"] = picture.get_has_alpha()
            said["filled"] = filled(picture)
            target = out / (model.name + ".png")
            picture.savev(str(target), "png", [], [])
            said["picture"] = str(target)
        except GLib.Error as error:
            said["ms"] = round((time.monotonic() - began) * 1000)
            said["error"] = error.message
        print(json.dumps(said), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
