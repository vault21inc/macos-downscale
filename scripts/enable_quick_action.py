#!/usr/bin/env python3
"""Enable Downscale Images in the current user's Finder Quick Actions list."""

import plistlib
import subprocess
import tempfile
from pathlib import Path


SERVICE_KEY = "(null) - Downscale Images - runWorkflowAsService"
MODES = {
    "ContextMenu": 1,
    "FinderPreview": 1,
    "ServicesMenu": 1,
    "TouchBar": 1,
}


def main() -> None:
    exported = subprocess.run(
        ["/usr/bin/defaults", "export", "pbs", "-"],
        check=True,
        capture_output=True,
    ).stdout
    preferences = plistlib.loads(exported)
    status = preferences.setdefault("NSServicesStatus", {})
    if status.get(SERVICE_KEY, {}).get("presentation_modes") == MODES:
        return
    status[SERVICE_KEY] = {"presentation_modes": MODES}

    with tempfile.TemporaryDirectory(prefix="downscale-") as temporary:
        path = Path(temporary) / "pbs.plist"
        with path.open("wb") as stream:
            plistlib.dump(preferences, stream)
        subprocess.run(["/usr/bin/defaults", "import", "pbs", str(path)], check=True)


if __name__ == "__main__":
    main()
