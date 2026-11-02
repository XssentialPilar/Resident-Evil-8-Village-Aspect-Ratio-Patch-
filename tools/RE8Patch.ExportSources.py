"""Save local dependency changes without modifying either Git index."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "reframework_src"


def git(directory, *args, success=(0,)):
    process = subprocess.run(["git", "-C", str(directory), *args], capture_output=True)
    if process.returncode not in success:
        raise RuntimeError(process.stderr.decode(errors="replace"))
    return process.stdout


def export():
    patch_dir = ROOT / "patches"
    patch_dir.mkdir(exist_ok=True)
    patch = git(SOURCE, "diff", "--binary", "HEAD", "--", ".", ":(exclude)dependencies/imgui")
    additions = git(SOURCE, "ls-files", "--others", "--exclude-standard", "-z").decode().split("\0")
    for relative in sorted(filter(None, additions)):
        if not relative.startswith("src/mods/re8/"):
            raise RuntimeError(f"Unreviewed dependency addition: {relative}")
        patch += git(SOURCE, "diff", "--no-index", "--binary", "--", "NUL", relative, success=(1,))
    imgui = SOURCE / "dependencies" / "imgui"
    imgui_patch = git(imgui, "diff", "--binary", "HEAD")
    (patch_dir / "RE8Framework.patch").write_bytes(patch)
    (patch_dir / "RE8ImGuiStartup.patch").write_bytes(imgui_patch)
    metadata = {
        "repository": "https://github.com/praydog/REFramework.git",
        "sourceRevision": git(SOURCE, "rev-parse", "HEAD").decode().strip(),
        "imguiRevision": git(imgui, "rev-parse", "HEAD").decode().strip(),
        "submodules": git(SOURCE, "submodule", "status").decode().splitlines(),
        "patches": {name: hashlib.sha256((patch_dir / name).read_bytes()).hexdigest()
                    for name in ("RE8Framework.patch", "RE8ImGuiStartup.patch")},
        "note": "Includes pre-existing local fixes and current development changes. No commit or release created.",
    }
    (ROOT / "external" / "REFramework.source.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    # Reverse-check against the current checkout proves the patch covers the
    # recorded changes, including newly added project-specific source headers.
    git(SOURCE, "apply", "--reverse", "--check", str(patch_dir / "RE8Framework.patch"))
    git(imgui, "apply", "--reverse", "--check", str(patch_dir / "RE8ImGuiStartup.patch"))
    print("Exported both dependency patches; reverse applicability checks passed.")


if __name__ == "__main__":
    export()
