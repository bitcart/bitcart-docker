import shutil
import subprocess
import tempfile
from pathlib import Path

DEMO_DIR = Path(__file__).parent
REPO_ROOT = DEMO_DIR.parent.parent

for old in DEMO_DIR.glob("*.whl"):
    old.unlink()

with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(
        [
            "uv",
            "build",
            "--package",
            "bitcart-compose-generator",
            "--wheel",
            "--out-dir",
            tmp,
        ],
        cwd=REPO_ROOT,
        check=True,
    )
    wheels = sorted(Path(tmp).glob("bitcart_compose_generator-*.whl"))
    if not wheels:
        raise RuntimeError("Build produced no wheel")
    wheel = shutil.move(str(wheels[-1]), DEMO_DIR / wheels[-1].name)

print(f"Done: {wheel}")
