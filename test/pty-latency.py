# Keystroke latency of an interactive shell, as a terminal sees it (Python 2.7 and 3).
#
#   python3 test/pty-latency.py [--cols 120] [--rows 30] [--keys TEXT] [--expect TEXT]
#                               [--enter N] -- COMMAND [ARG...]
#
# Starts COMMAND in a pseudo-terminal (answering the terminal queries ble.sh, fish and
# tmux send), waits for the first prompt, then types TEXT one key at a time. For each key
# it records how long the program kept drawing: the time from the key to the last byte
# written before 150 ms of quiet. That is the moment the screen is final, suggestion
# included, whether the suggestion is drawn with the key or after it. With --expect, the
# first key's time is instead the time until TEXT (the grey suggestion's tail) appears.
# --enter N then presses Ctrl-U, types `true` and Enter N times and times each new prompt.
# Prints one line per measure, in milliseconds:
#   prompt 412        spawn to the first prompt (last byte before the quiet)
#   first 9           first key to the suggestion (or to the quiet without --expect)
#   keys 3 2 4 ...    each following key
#   enter 35 33 ...   Enter to the next prompt
# With --startup N it instead runs COMMAND N times without a terminal (stdin and stdout
# /dev/null) and prints "startup MEDIAN min..max" (use it as: --startup 10 -- zsh -i -c exit).
import os, pty, select, sys, time, signal, struct, fcntl, termios

QUIET = 0.15
DEBUG = os.environ.get("PTY_LATENCY_DEBUG")


def main(argv):
    cols, rows, keys, expect, enters, startup = 120, 30, "zq-rihla-p", "", 0, 0
    i = 0
    while i < len(argv) and argv[i] != "--":
        a = argv[i]
        if a == "--cols": cols = int(argv[i + 1]); i += 1
        elif a == "--rows": rows = int(argv[i + 1]); i += 1
        elif a == "--keys": keys = argv[i + 1]; i += 1
        elif a == "--expect": expect = argv[i + 1]; i += 1
        elif a == "--enter": enters = int(argv[i + 1]); i += 1
        elif a == "--startup": startup = int(argv[i + 1]); i += 1
        i += 1
    cmd = argv[i + 1:]
    if startup:
        import subprocess
        null = open(os.devnull, "r+")
        ts = []
        for _ in range(startup):
            s = time.time()
            subprocess.call(cmd, stdin=null, stdout=null, stderr=null)
            ts.append((time.time() - s) * 1000)
        ts.sort()
        n = len(ts)
        med = ts[n // 2] if n % 2 else (ts[n // 2 - 1] + ts[n // 2]) / 2
        print("startup %d %d..%d" % (med, ts[0], ts[-1]))
        return 0
    t0 = time.time()
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvp(cmd[0], cmd)
        finally:
            os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    buf = [b""]

    def answer(data):
        # Device attributes (DA1, DA2), XTVERSION, cursor position, kitty keyboard query.
        out = b""
        if b"\x1b[c" in data or b"\x1b[0c" in data: out += b"\x1b[?62;22c"
        if b"\x1b[>c" in data or b"\x1b[>0c" in data: out += b"\x1b[>1;10;0c"
        if b"\x1b[>0q" in data: out += b"\x1bP>|pty-latency\x1b\\"
        if b"\x1b[6n" in data: out += b"\x1b[1;1R"
        if b"\x1b[?u" in data: out += b"\x1b[?0u"
        if out: os.write(fd, out)

    def read_until(deadline, want=None):
        # Returns the time of the last byte read (or of `want` appearing) and stops at
        # QUIET seconds without output, at `want`, or at the deadline.
        last = None
        start = len(buf[0])
        while True:
            now = time.time()
            if now > deadline: return last
            r, _, _ = select.select([fd], [], [], max(0.0, min(0.02, deadline - now)))
            if not r:
                if want is None and last is not None and time.time() - last >= QUIET: return last
                continue
            try:
                d = os.read(fd, 65536)
            except OSError:
                return last
            if not d: return last
            last = time.time()
            if DEBUG: sys.stderr.write("%.4f %d %r\n" % (last, len(d), d[:50]))
            buf[0] += d
            answer(d)
            if want is not None and want.encode() in buf[0][start:]: return last

    # First prompt: output, then quiet. ble.sh and fish may draw in several bursts, so
    # wait for a longer quiet once something has been drawn.
    first = None
    end = time.time() + 30
    while time.time() < end:
        t = read_until(end)
        if t is None: break
        first = t
        r, _, _ = select.select([fd], [], [], 1.0)
        if not r: break
    if first is None:
        print("prompt none")
        return 1
    print("prompt %d" % ((first - t0) * 1000))
    res = []
    for n, k in enumerate(keys):
        s = time.time()
        os.write(fd, k.encode())
        if n == 0 and expect:
            t = read_until(s + 5, expect)
            print("first %s" % ("none" if t is None or expect.encode() not in buf[0] else "%d" % ((t - s) * 1000)))
            read_until(time.time() + 2)
            continue
        t = read_until(s + 5)
        if n == 0:
            print("first %s" % ("none" if t is None else "%d" % ((t - s) * 1000)))
        else:
            res.append("none" if t is None else "%d" % ((t - s) * 1000))
    print("keys " + " ".join(res))
    if enters:
        os.write(fd, b"\x15")
        read_until(time.time() + 2)
        ent = []
        for _ in range(enters):
            os.write(fd, b"true")
            read_until(time.time() + 2)
            s = time.time()
            if DEBUG: sys.stderr.write("%.4f ENTER\n" % s)
            os.write(fd, b"\r")
            t = read_until(s + 10)
            ent.append("none" if t is None else "%d" % ((t - s) * 1000))
        print("enter " + " ".join(ent))
    if os.environ.get("PTY_LATENCY_DUMP"):
        open(os.environ["PTY_LATENCY_DUMP"], "wb").write(buf[0])
    try:
        os.kill(pid, signal.SIGHUP)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
