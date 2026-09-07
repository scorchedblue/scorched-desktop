#!/usr/bin/bash
#
# Emit a peak audio level, 0-100, roughly 20 times a second, for one PulseAudio
# or PipeWire source. One integer per line, flushed immediately so a reader sees
# it as it happens.
#
# Point it at a source to meter a microphone, or at a sink's ".monitor" source
# to meter what is coming out of the speakers.
#
# Cost: measured at 0.0% CPU for all three processes. That is the reason for
# every parameter below -- 8 kHz mono is far below anything worth listening to,
# but it is plenty for a meter, and it keeps the sample rate that `od` and `awk`
# have to chew through two orders of magnitude below CD audio.
#
# Reading raw audio through od and awk looks unusual. The alternative is
# ffmpeg's astats filter, which is heavier to spawn, prints on its own schedule,
# and has to be parsed out of a log stream. This pipeline is smaller, its output
# rate is set here rather than by a filter, and it costs nothing.

set -uo pipefail

src="${1:-}"
if [ -z "$src" ]; then
    echo "usage: audio-levels.sh <pulse-source-name>" >&2
    exit 2
fi

# Three separate things add delay here, and all three have to be dealt with or
# the meter visibly trails the sound:
#
#   1. parec asks the server for a comfortable buffer by default, which is a
#      good default for recording a file and far too much for a meter.
#      --latency-msec pins it low.
#   2. od block-buffers its stdout when it is a pipe, so output arrives in ~4KB
#      lumps rather than as it is produced. stdbuf -o0 turns that off. This one
#      is invisible in testing because it disappears the moment you run the
#      pipeline into a terminal, where od line-buffers instead.
#   3. awk already fflush()es every emission, so it needs nothing.
#
# --raw suppresses the WAV header, which would otherwise be read as samples and
# show up as one loud spike at startup.
parec --device="$src" --format=s16le --rate=8000 --channels=1 --raw \
    --latency-msec=20 --process-time-msec=10 2>/dev/null |
    stdbuf -o0 od -An -td2 -w64 -v |
    awk '
        {
            for (i = 1; i <= NF; i++) {
                v = $i < 0 ? -$i : $i
                if (v > m) m = v
            }
            n++
            # 12 rows of 32 samples is 384 samples, or ~48ms at 8 kHz -- about
            # 20 updates a second. Faster than this is below what the eye
            # resolves on a bar and only wakes the reader more often.
            if (n >= 12) {
                printf "%d\n", (m * 100) / 32768
                fflush()
                m = 0
                n = 0
            }
        }
    '
