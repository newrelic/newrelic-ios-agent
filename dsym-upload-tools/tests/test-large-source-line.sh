#!/bin/sh

# 2026 New Relic
# End-to-end test for run-symbol-tool.swift with a source line whose code range is >= 1 MB.
#
# `symbols` right-aligns the size in an 8-char field, so a full-width size has no space after "(":
#     0x0000000100000340 (0x110000) big.c:5
# run-symbol-tool used to fail map conversion on that line and fall back to uploading the dSYM.
#
# The test builds a dSYM containing such a line, runs the real script against a local capture server,
# and asserts that a map (not a dSYM) is uploaded and contains the line.
#
# Usage: tests/test-large-source-line.sh [path/to/run-symbol-tool.swift]

set -eu

TESTS_DIR=$( cd "$( dirname "$0" )" && pwd )
SCRIPT=${1:-"$TESTS_DIR/../run-symbol-tool.swift"}
WORK=$( mktemp -d -t run-symbol-tool-test )
SERVER_PID=""

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $1"
    echo "---- run-symbol-tool output ----"
    cat "$WORK/output.log" 2>/dev/null || true
    exit 1
}

# 1. Fabricate a dSYM. The .fill emits 0x110000 bytes of NOPs attributed to a single source line.
mkdir -p "$WORK/build" "$WORK/dsyms" "$WORK/uploads"
cat > "$WORK/build/big.c" <<'EOF'
int small(int a) {
    return a + 1;
}
void huge(void) {
    __asm__ volatile(".fill 0x44000, 4, 0xd503201f");
}
int main(void) { huge(); return small(1); }
EOF
clang -g -O0 -arch arm64 -c "$WORK/build/big.c" -o "$WORK/build/big.o"
clang -arch arm64 "$WORK/build/big.o" -o "$WORK/build/Big"
dsymutil "$WORK/build/Big" -o "$WORK/dsyms/Big.dSYM"

symbols -arch arm64 "$WORK/dsyms/Big.dSYM" | grep -Eq '\(0x[0-9a-f]{6}\) big\.c:5$' \
    || fail "fixture does not contain a full-width source line size"

# 2. Capture server: saves the file part of each multipart POST as uploads/<endpoint>-<n>.bin, replies 201.
cat > "$WORK/server.py" <<'EOF'
import email.parser, email.policy, http.server, os, sys

uploads = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        header = f"Content-Type: {self.headers['Content-Type']}\r\n\r\n".encode()
        message = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(header + body)
        endpoint = self.path.strip("/")
        count = len([f for f in os.listdir(uploads) if f.startswith(endpoint + "-")])
        for part in message.iter_parts():
            with open(os.path.join(uploads, f"{endpoint}-{count}.bin"), "wb") as f:
                f.write(part.get_payload(decode=True))
        self.send_response(201)
        self.end_headers()

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(uploads, "..", "port"), "w") as f:
    f.write(str(server.server_port))
server.serve_forever()
EOF
/usr/bin/python3 -I "$WORK/server.py" "$WORK/uploads" &
SERVER_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$WORK/port" ] && break; sleep 0.5; done
[ -s "$WORK/port" ] || fail "capture server did not start"

# 3. Run the real script. The app token must not contain "x", which would switch to a region URL.
echo "Running $SCRIPT"
DWARF_DSYM_FOLDER_PATH="$WORK/dsyms" \
EFFECTIVE_PLATFORM_NAME="-iphoneos" \
MARKETING_VERSION="1.0" \
DSYM_UPLOAD_URL="http://127.0.0.1:$( cat "$WORK/port" )" \
    /usr/bin/xcrun --sdk macosx swift "$SCRIPT" "TESTAPPTOKEN" --debug > "$WORK/output.log" 2>&1 \
    || fail "run-symbol-tool exited with an error"

# 4. Assert a map was uploaded instead of falling back to the dSYM.
grep -q "Falling back to upload zipped dSYM" "$WORK/output.log" && fail "map conversion failed and fell back to dSYM upload"
[ -f "$WORK/uploads/map-0.bin" ] || fail "no map was uploaded"
[ ! -f "$WORK/uploads/symbol-0.bin" ] || fail "a dSYM was uploaded"

mkdir -p "$WORK/map"
ditto -x -k "$WORK/uploads/map-0.bin" "$WORK/map"
MAP_FILE=$( find "$WORK/map" -name '*.map' | head -n 1 )
[ -n "$MAP_FILE" ] || fail "uploaded archive does not contain a .map file"

grep -q '^0x0000000100000340 huge (big.c:5)$' "$MAP_FILE" || fail "map is missing the full-width source line"
grep -q '^0x0000000100000330 small (big.c:2)$' "$MAP_FILE" || fail "map is missing a regular source line"

echo "PASS: map uploaded with full-width source line"
