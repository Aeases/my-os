import argparse
import array
import asyncio
import logging
import os
import signal
import sys

import pyatv
import pyatv.protocols.raop as raop
from pyatv.const import Protocol
from pyatv.interface import MediaMetadata
from pyatv.protocols.raop.audio_source import AudioSource

RATE = 44100
CHANNELS = 2
SAMPLE_SIZE = 2
FRAME = CHANNELS * SAMPLE_SIZE

PREBUFFER = int(0.25 * RATE) * FRAME
# more than this queued means the writer runs faster than we send: drop the excess
MAX_BUFFER = int(0.75 * RATE) * FRAME
LIVE_DURATION = 24 * 60 * 60

log = logging.getLogger("airplay-sender")


class FifoSource(AudioSource):
    def __init__(self, path, name):
        self.name = name
        self.fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
        self.buf = bytearray()
        self.primed = False
        self.underruns = 0
        self.trimmed = 0
        asyncio.get_running_loop().add_reader(self.fd, self._read)

    def _read(self):
        try:
            while chunk := os.read(self.fd, 65536):
                self.buf += chunk
        except BlockingIOError:
            pass
        if len(self.buf) > MAX_BUFFER:
            drop = (len(self.buf) - PREBUFFER) // FRAME * FRAME
            del self.buf[:drop]
            self.trimmed += drop // FRAME
            log.info("trimmed %d frames (%d total)", drop // FRAME, self.trimmed)

    async def readframes(self, nframes):
        # never block: pyatv paces packets from the first one, and anything late is
        # dropped by the speaker
        size = nframes * FRAME
        if not self.primed:
            if len(self.buf) < PREBUFFER:
                return bytes(size)
            self.primed = True
        if len(self.buf) < size:
            self.underruns += 1
            self.primed = False
            out = bytes(self.buf) + bytes(size - len(self.buf))
            self.buf.clear()
        else:
            out = bytes(self.buf[:size])
            del self.buf[:size]
        # pyatv sends samples big-endian, despite AudioSource's docstring
        # (its own sources byteswap the same way)
        samples = array.array("h", out)
        if sys.byteorder == "little":
            samples.byteswap()
        return samples.tobytes()

    async def close(self):
        if self.fd is None:
            return
        asyncio.get_running_loop().remove_reader(self.fd)
        os.close(self.fd)
        self.fd = None

    async def get_metadata(self):
        return MediaMetadata(title=self.name, duration=LIVE_DURATION)

    @property
    def sample_rate(self):
        return RATE

    @property
    def channels(self):
        return CHANNELS

    @property
    def sample_size(self):
        return SAMPLE_SIZE

    @property
    def duration(self):
        return LIVE_DURATION # duration of 0 makes it finish immediately


_open_source = raop.open_source


async def _open_passthrough(source, *args):
    if isinstance(source, AudioSource):
        return source
    return await _open_source(source, *args)


raop.open_source = _open_passthrough


async def find(host, timeout):
    loop = asyncio.get_running_loop()
    for conf in await pyatv.scan(loop, hosts=[host], protocol=Protocol.RAOP, timeout=timeout):
        return conf
    raise SystemExit(f"no AirPlay speaker answered at {host}")


async def run(args):
    source = FifoSource(args.fifo, args.title)
    conf = await find(args.host, args.scan_timeout)
    source.name = source.name or conf.name
    log.info("connecting to %s (%s)", conf.name, args.host)
    atv = await pyatv.connect(conf, asyncio.get_running_loop(), protocol=Protocol.RAOP)
    if args.volume is not None:
        await atv.audio.set_volume(args.volume)
    stream = asyncio.ensure_future(atv.stream.stream_file(source))

    stop = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        asyncio.get_running_loop().add_signal_handler(sig, stop.set)
    stopped = asyncio.ensure_future(stop.wait())
    await asyncio.wait([stream, stopped], return_when=asyncio.FIRST_COMPLETED)

    log.info("stopping (underruns %d, trimmed %d frames)", source.underruns, source.trimmed)
    stream.cancel()
    try:
        await stream
    except (asyncio.CancelledError, Exception) as err:
        if not isinstance(err, asyncio.CancelledError):
            log.error("stream failed: %s", err)
    atv.close()
    await source.close()
    return 0 if stop.is_set() else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", required=True, help="speaker address")
    parser.add_argument("--fifo", required=True, help="FIFO the pipe sink writes into")
    parser.add_argument("--title", help="track title shown on the speaker")
    parser.add_argument("--volume", type=float, help="speaker volume, 0-100")
    parser.add_argument("--scan-timeout", type=float, default=5)
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(levelname)s %(name)s: %(message)s")
    sys.exit(asyncio.run(run(args)))


if __name__ == "__main__":
    main()
