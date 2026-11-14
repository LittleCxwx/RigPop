"""Fetch only Windows release binaries from the official versioned template ZIP."""
import io
import pathlib
import urllib.request
import zipfile

VERSION = "4.7.2"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=40) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def read(self, count=-1):
        if count < 0:
            count = self.length - self.position
        if count == 0:
            return b""
        end = min(self.length, self.position + count) - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.position}-{end}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor Range; refusing full archive download")
            data = response.read()
        self.position += len(data)
        return data


if __name__ == "__main__":
    destination = pathlib.Path(__file__).resolve().parent.parent / "build" / "templates"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip(URL)) as archive:
        entries = [item for item in archive.infolist() if item.filename.endswith("windows_release_x86_64.exe") or item.filename.endswith("windows_release_x86_64_console.exe")]
        if not entries:
            raise RuntimeError("Windows x86_64 release templates not found")
        for entry in entries:
            print(f"Downloading {entry.filename}: {entry.compress_size:,} bytes", flush=True)
            output = destination / pathlib.PurePosixPath(entry.filename).name
            output.write_bytes(archive.read(entry))
            print(f"Verified ZIP CRC and wrote {output}", flush=True)
