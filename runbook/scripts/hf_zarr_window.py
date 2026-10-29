"""hf_zarr_window.py <hf path of an OME-Zarr> <level> <z0> <z1> <local out .ome.zarr> [threads] - copy the chunks of one
level that overlap level-z [z0, z1) from a Hugging Face bucket or dataset to a local OME-Zarr, unchanged (same
compression and chunk files, so values are bit-identical). Group metadata (.zattrs, .zgroup) and the level's .zarray
come along; other levels are not copied. Prints files, bytes, seconds and any failures (retried 3 times).
Anonymous Hugging Face API calls are limited (500 per 5 min): each z-slab is listed with one recursive, paged call,
429 replies are waited out, and chunk files already present locally are skipped (so a rerun resumes).
Used for P9: the community lasagna field of PHerc0175A (read-only input, CC BY-NC 4.0)."""
import json, os, sys, time
from concurrent.futures import ThreadPoolExecutor
from huggingface_hub import HfFileSystem

src, level, z0, z1, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
threads = int(sys.argv[6]) if len(sys.argv) > 6 else 16
fs = HfFileSystem()
os.makedirs(f"{out}/{level}", exist_ok=True)
for meta in (".zattrs", ".zgroup"):
    try:
        open(f"{out}/{meta}", "wb").write(fs.cat(f"{src}/{meta}"))
    except FileNotFoundError:
        pass
zarray = fs.cat(f"{src}/{level}/.zarray"); open(f"{out}/{level}/.zarray", "wb").write(zarray)
a = json.loads(zarray); cz = a["chunks"][0]; sep = a.get("dimension_separator", ".")
assert sep == "/", "expects nested chunk keys"
zis = range(z0 // cz, -(-min(z1, a["shape"][0]) // cz))


def listing(path):
    """Every file under path, recursively, in as few API calls as the paging allows; waits out rate limits."""
    for attempt in range(6):
        try:
            return fs.find(path)
        except Exception as e:
            if "429" not in str(e) or attempt == 5:
                raise
            print(f"rate limited listing {path.split('/')[-1]}; waiting 65 s", flush=True); time.sleep(65)


def copy(rel):
    if os.path.exists(f"{out}/{level}/{rel}") and os.path.getsize(f"{out}/{level}/{rel}") > 0:
        return 0  # already copied by an earlier run
    for attempt in range(3):
        try:
            data = fs.cat(f"{src}/{level}/{rel}")
            path = f"{out}/{level}/{rel}"; os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path + ".part", "wb").write(data); os.replace(path + ".part", path)
            return len(data)
        except FileNotFoundError:
            return 0  # empty chunk (fill value), absent upstream as well
        except Exception as e:  # rate limit or network: back off and retry
            if attempt == 2:
                print(f"FAILED {rel}: {type(e).__name__} {str(e)[:120]}", flush=True); return -1
            time.sleep(65 if "429" in str(e) else 5 * (attempt + 1))


t = time.time(); files = []
for zi in zis:
    root = f"{src}/{level}/"
    files += [x.split(root, 1)[1] for x in listing(f"{src}/{level}/{zi}")]
print(f"{len(files)} chunk files listed in {time.time() - t:.0f}s", flush=True)
with ThreadPoolExecutor(threads) as pool:
    sizes = list(pool.map(copy, files))
failed = sum(1 for s in sizes if s < 0)
print(f"copied {len(files) - failed} files, {sum(s for s in sizes if s > 0) / 1e9:.2f} GB in {time.time() - t:.0f}s; "
      f"failed {failed}", flush=True)
sys.exit(1 if failed else 0)
