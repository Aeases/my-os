import asyncio
import json
import logging
import os
import re
import signal
import socket
import sys
import time

SINK_PREFIX = "airplay."
RUNTIME_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "airplay-bridge")
RESYNC_SECONDS = 5
GONE_GRACE_SECONDS = 60
IDLE_STOP_SECONDS = 15

log = logging.getLogger("airplay-bridge")


def unescape(name):
    # avahi-browse -p escapes as \DDD (decimal)
    return re.sub(r"\\(\d{3})", lambda m: chr(int(m.group(1))), name)


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "speaker"


async def run(*cmd, check=True):
    proc = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE,
                                                stderr=asyncio.subprocess.PIPE)
    out, err = await proc.communicate()
    if check and proc.returncode:
        raise RuntimeError(f"{cmd[0]} {cmd[1]} failed: {err.decode().strip()}")
    return out.decode()


class Speaker:
    def __init__(self, ident, name, host):
        self.ident, self.name, self.host = ident, name, host
        self.key = None
        self.last_seen = time.monotonic()


class Bridge:
    def __init__(self):
        self.speakers = {}  # ident -> Speaker
        self.running = set()
        self.idle_since = {}
        self.adopted = {}  # key -> first seen, for sinks from an earlier run
        self.local_host = socket.gethostname().split(".")[0].lower() + ".local"

    def keys(self):
        return {s.key: s for s in self.speakers.values() if s.key}

    def assign_key(self, speaker):
        taken = self.keys()
        key = slug(speaker.name)
        if key in taken and taken[key] is not speaker:
            key = f"{key}-{slug(speaker.ident)[-4:]}"
        speaker.key = key

    # discovery

    def on_browse(self, line):
        fields = line.rstrip("\n").split(";")
        if fields[0] == "=" and len(fields) >= 9 and fields[2] == "IPv4":
            ident, _, name = unescape(fields[3]).partition("@")
            host, addr = fields[6].lower(), fields[7]
            if host == self.local_host or not name:
                return
            speaker = self.speakers.get(ident)
            if speaker is None:
                speaker = self.speakers[ident] = Speaker(ident, name, addr)
                self.assign_key(speaker)
                log.info("found %s at %s", name, addr)
            speaker.host, speaker.last_seen = addr, time.monotonic()
            self.write_env(speaker)

    async def browse(self):
        proc = await asyncio.create_subprocess_exec(
            "avahi-browse", "-p", "-r", "-k", "_raop._tcp", stdout=asyncio.subprocess.PIPE)
        while line := await proc.stdout.readline():
            self.on_browse(line.decode(errors="replace"))
        raise RuntimeError("avahi-browse exited")

    async def refresh_seen(self):
        # resolved entries only print once; a one-shot browse refreshes last_seen
        out = await run("avahi-browse", "-p", "-r", "-k", "-t", "_raop._tcp", check=False)
        for line in out.splitlines():
            self.on_browse(line)

    # sinks

    def fifo(self, key):
        return os.path.join(RUNTIME_DIR, f"{key}.fifo")

    def write_env(self, speaker):
        path = os.path.join(RUNTIME_DIR, f"{speaker.key}.env")
        text = f"HOST={speaker.host}\nTITLE={speaker.name}\n"
        try:
            with open(path) as f:
                if f.read() == text:
                    return
        except FileNotFoundError:
            pass
        with open(path + ".tmp", "w") as f:
            f.write(text)
        os.replace(path + ".tmp", path)

    async def our_sinks(self):
        sinks = json.loads(await run("pactl", "-f", "json", "list", "sinks"))
        return {s["name"][len(SINK_PREFIX):]: s for s in sinks if s["name"].startswith(SINK_PREFIX)}

    async def load_sink(self, speaker):
        description = speaker.name.replace('"', "'")
        await run("pactl", "load-module", "module-pipe-sink",
                  f"file={self.fifo(speaker.key)}", f"sink_name={SINK_PREFIX}{speaker.key}",
                  "format=s16le", "rate=44100", "channels=2",
                  f'sink_properties=device.description="{description}" device.icon_name="audio-speakers"')
        log.info("added output for %s", speaker.name)

    async def unload_sink(self, key, sink):
        await self.stop_sender(key)
        await run("pactl", "unload-module", str(sink["owner_module"]), check=False)
        for path in (self.fifo(key), os.path.join(RUNTIME_DIR, f"{key}.env")):
            try:
                os.unlink(path)
            except FileNotFoundError:
                pass
        log.info("removed output %s", key)

    async def resync(self):
        now = time.monotonic()
        sinks = await self.our_sinks()
        keys = self.keys()
        for key, speaker in keys.items():
            if key not in sinks:
                await self.load_sink(speaker)
        for key, sink in sinks.items():
            speaker = keys.get(key)
            if speaker is None:
                first = self.adopted.setdefault(key, now)
                if now - first > GONE_GRACE_SECONDS:
                    await self.unload_sink(key, sink)
                    self.adopted.pop(key)
            elif now - speaker.last_seen > GONE_GRACE_SECONDS:
                log.info("%s is gone", speaker.name)
                await self.unload_sink(key, sink)
                del self.speakers[speaker.ident]
        await self.follow_sinks()

    # senders

    async def start_sender(self, key):
        log.info("%s started playing", key)
        await run("systemctl", "--user", "start", f"airplay-sender@{key}.service", check=False)

    async def stop_sender(self, key):
        self.running.discard(key)
        self.idle_since.pop(key, None)
        await run("systemctl", "--user", "stop", f"airplay-sender@{key}.service", check=False)

    async def follow_sinks(self):
        now = time.monotonic()
        keys = self.keys()
        for key, sink in (await self.our_sinks()).items():
            if key not in keys:
                continue
            if sink["state"] == "RUNNING":
                self.idle_since.pop(key, None)
                if key not in self.running:
                    self.running.add(key)
                    await self.start_sender(key)
            elif key in self.running:
                since = self.idle_since.setdefault(key, now)
                if now - since >= IDLE_STOP_SECONDS:
                    log.info("%s idle, stopping sender", key)
                    await self.stop_sender(key)

    async def events(self):
        proc = await asyncio.create_subprocess_exec("pactl", "subscribe", stdout=asyncio.subprocess.PIPE)
        while line := await proc.stdout.readline():
            if b"on sink #" in line:
                await self.follow_sinks()
        raise RuntimeError("pactl subscribe exited; pipewire-pulse went away")

    async def ticker(self):
        while True:
            await asyncio.sleep(RESYNC_SECONDS)
            await self.refresh_seen()
            await self.resync()

    async def shutdown(self):
        for key, sink in (await self.our_sinks()).items():
            await self.unload_sink(key, sink)


async def main_async():
    os.makedirs(RUNTIME_DIR, exist_ok=True)
    bridge = Bridge()
    stop = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    tasks = [asyncio.ensure_future(t) for t in (bridge.browse(), bridge.events(), bridge.ticker())]
    stopped = asyncio.ensure_future(stop.wait())
    done, _ = await asyncio.wait([*tasks, stopped], return_when=asyncio.FIRST_COMPLETED)
    for task in tasks:
        task.cancel()
    await bridge.shutdown()
    failed = [t for t in done if t is not stopped and t.exception()]
    for task in failed:
        log.error("%s", task.exception())
    return 1 if failed else 0


def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    sys.exit(asyncio.run(main_async()))


if __name__ == "__main__":
    main()
