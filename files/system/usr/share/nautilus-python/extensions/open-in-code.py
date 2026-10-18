# Nautilus "Open in Code". Paths are passed as arguments, never through a shell.

import os
import subprocess

from gi.repository import GObject, Nautilus

CODE = ["code"]


class OpenInCodeExtension(GObject.GObject, Nautilus.MenuProvider):
    def _launch(self, _menu, files):
        paths = [f.get_location().get_path() for f in files]
        paths = [p for p in paths if p]  # smb://, mtp:// etc. have no local path
        if not paths:
            return
        args = ["--new-window"] if any(os.path.isdir(p) for p in paths) else []
        subprocess.Popen(CODE + args + paths, start_new_session=True)

    def get_file_items(self, *args):
        item = Nautilus.MenuItem(name="OpenInCode::Files", label="Open in Code")
        item.connect("activate", self._launch, args[-1])
        return [item]

    def get_background_items(self, *args):
        item = Nautilus.MenuItem(name="OpenInCode::Background", label="Open in Code")
        item.connect("activate", self._launch, [args[-1]])
        return [item]
