#!/bin/zsh

# Maximize screen
sleep 0.5
if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
  SCRIPT=$(mktemp --suffix=.js)
  echo "workspace.activeWindow.setMaximize(true, true)" > "$SCRIPT"
  ID=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$SCRIPT" 2>/dev/null)
  qdbus6 org.kde.KWin "/Scripting/Script${ID}" run >/dev/null 2>&1
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$SCRIPT" >/dev/null 2>&1
  rm -f "$SCRIPT"
else
  wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz 2>/dev/null || \
  xdotool getactivewindow windowstate --add MAXIMIZED_VERT MAXIMIZED_HORZ 2>/dev/null
fi

# Colors
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Load config ──────────────────────────────────────────────────────────────

SCRIPT_DIR="${0:A:h}"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "${RED}Error: config.json not found at $CONFIG_FILE${RESET}"
  exit 1
fi

RPC_USER=$(jq -r '.user' "$CONFIG_FILE")
RPC_PASS=$(jq -r '.pass' "$CONFIG_FILE")
RPC_NODE=$(jq -r '.node' "$CONFIG_FILE")
RPC_URL="http://$RPC_NODE/"

header() { echo "${BOLD}${CYAN}$1${RESET}"; }

colorize_row() {
  local line="$1"
  if echo "$line" | grep -q "inbound"; then
    echo "${DIM}${line}${RESET}"
  elif echo "$line" | grep -q "block-relay"; then
    echo "${YELLOW}${line}${RESET}"
  elif echo "$line" | grep -q "outbound-full-relay"; then
    echo "${GREEN}${line}${RESET}"
  elif echo "$line" | grep -qE "ADDRESS|---"; then
    echo "${BOLD}${line}${RESET}"
  else
    echo "${RED}${line}${RESET}"
  fi
}


rpc() {
  curl -s --user "$RPC_USER:$RPC_PASS" \
    --data-binary "{\"jsonrpc\":\"1.0\",\"id\":\"test\",\"method\":\"$1\",\"params\":[]}" \
    -H 'content-type: text/plain;' "$RPC_URL"
}

# $1 = netinfo JSON file, $2 = peer coords file (lat|lon|label)
render_top() {
  python3 - "$1" "$2" << 'PYEOF'
import sys, json, re

ANSI_ESC = re.compile(r'\033\[[0-9;]*m')
def vlen(s): return len(ANSI_ESC.sub('', s))
def pad(s, w): return s + ' ' * max(0, w - vlen(s))

BOLD        = "\033[1m"
CYAN        = "\033[0;36m"
YELLOW_BOLD = "\033[1;33m"
RESET       = "\033[0m"

def h(s): return f"{BOLD}{CYAN}{s}{RESET}"

# ── Left column: network info ─────────────────────────────────────────────────
with open(sys.argv[1]) as f:
    net = json.load(f)['result']

left = []
left.append(h("=== Node Info ==="))
left.append(f"Client:    {net['subversion']}")
left.append(f"Version:   {net['version']}")
left.append(f"Protocol:  {net['protocolversion']}")
left.append("")
left.append(h("=== Networks ==="))
left.append(f"{'NAME':<7} {'REACHABLE':<10} {'LIMITED':<8} PROXY")
for n in net['networks']:
    proxy = n['proxy'] if n['proxy'] else '-'
    left.append(f"{n['name']:<7} {str(n['reachable']).lower():<10} {str(n['limited']).lower():<8} {proxy}")
left.append("")
left.append(h("=== Connections ==="))
left.append(f"Total:    {net['connections']}")
left.append(f"Inbound:  {net['connections_in']}")
left.append(f"Outbound: {net['connections_out']}")
left.append("")
left.append(h("=== Local Addresses ==="))
left.append(f"{'ADDRESS':<50} {'PORT':<6} SCORE")
for a in net['localaddresses']:
    left.append(f"{a['address']:<50} {a['port']:<6} {a['score']}")
left.append("")
left.append(f"Relay Fee:   {net['relayfee']:.8f} BTC/kvB")
left.append(f"Local Relay: {str(net['localrelay']).lower()}")

# ── Right column: map ─────────────────────────────────────────────────────────
MAP_STR = r"""90N-+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-90N
    |           . _..::__:  ,-"-"._        |7       ,     _,.__             |
    |   _.___ _ _<_>`!(._`.`-.    /         _._     `_ ,_/  '  '-._.---.-.__|
    |>.{     " " `-==,',._\{  \  / {)      / _ ">_,-' `                mt-2_|
60N-+  \_.:--.       `._ )`^-. "'       , [_/(                       __,/-' +-60N
    | '"'     \         "    _L        oD_,--'                )     /. (|   |
    |          |           ,'          _)_.\\._<> 6              _,' /  '   |
    |          `.         /           [_/_'` `"(                <'}  )      |
30N-+           \\    .-. )           /   `-'"..' `:._          _)  '       +-30N
    |    `        \  (  `(           /         `:\  > \  ,-^.  /' '         |
    |              `._,   ""         |           \`'   \|   ?_)  {\         |
    |                 `=.---.        `._._       ,'     "`  |' ,- '.        |
000-+                   |    `-._         |     /          `:`<_|h--._      +-000
    |                   (        >        .     | ,          `=.__.`-'\     |
    |                    `.     /         |     |{|              ,-.,\     .|
    |                     |   ,'           \   / `'            ,"     \     |
30S-+                     |  /              |_'                |  __  /     +-30S
    |                     | |                                  '-'  `-'   \.|
    |                     |/                                         "    / |
    |                     \.                                             '  |
60S-+                                                                       +-60S
    |                      ,/            ______._.--._ _..---.---------._   |
    |     ,-----"-..?----_/ )      __,-'"             "                  (  |
    |-.._(                  `-----'                                       `-|
90S-+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-90S
    Map 1998 Matthew Thomas.|Freely usable as long as this|line is included.|"""

map_lines = MAP_STR.split('\n')
grid = [list(l.ljust(81)) for l in map_lines]

with open(sys.argv[2]) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        parts = line.split("|")
        if len(parts) == 3:
            try:
                lat, lon = float(parts[0]), float(parts[1])
                r = max(0, min(len(grid)-1, int(round((90 - lat) / 180 * 24))))
                c = max(0, min(80,          int(round(4 + (lon + 180) / 30 * 6))))
                grid[r][c] = '\x00'
            except ValueError:
                pass

right = []
for row in grid:
    out = ""
    for ch in row:
        out += (YELLOW_BOLD + 'X' + RESET) if ch == '\x00' else ch
    right.append(out)

# ── Print side by side ────────────────────────────────────────────────────────
LEFT_WIDTH = 90
GAP = "  "
rows = max(len(left), len(right))
left  += [''] * (rows - len(left))
right += [''] * (rows - len(right))

for l, r in zip(left, right):
    print(pad(l, LEFT_WIDTH) + GAP + r)
PYEOF
}

# ─── Fetch data ───────────────────────────────────────────────────────────────

NETINFO_FILE=$(mktemp)
PEER_TMP=$(mktemp)

rpc getnetworkinfo > "$NETINFO_FILE"

# ─── Print network info immediately (plain, no map yet) ───────────────────────

render_top "$NETINFO_FILE" "$PEER_TMP"   # PEER_TMP is empty - renders without markers
echo ""

# ─── Fetch peers ──────────────────────────────────────────────────────────────

PEERINFO=$(rpc getpeerinfo)

# ─── Peer Summary ─────────────────────────────────────────────────────────────

header "=== Peer Summary ==="
echo "$PEERINFO" | jq -r '
  .result |
  "Total peers: \(length)",
  "Inbound:     \([.[] | select(.inbound == true)] | length)",
  "Outbound:    \([.[] | select(.inbound == false)] | length)"'

echo ""
header "=== Peer List ==="

# Collect raw peer data
PEERS=()
while IFS= read -r line; do
  PEERS+=("$line")
done < <(echo "$PEERINFO" | jq -r '.result[] | "\(.addr)|\(.subver)|\(.connection_type)|\((.pingtime // 0) * 1000 | round)ms|\(.synced_blocks)"')

TOTAL=${#PEERS[@]}

GEOS=()
LATS=()
LONS=()

# ─── Batch geo lookup ─────────────────────────────────────────────────────────

# Extract the address portion (strip port) for each peer
IP_ADDRS=()
for i in $(seq 1 $TOTAL); do
  IP_ADDRS+=("$(echo "${PEERS[$i]}" | cut -d'|' -f1 | sed 's/:.*//')")
done

# Build JSON array and fire a single POST to ip-api.com/batch
BATCH_JSON=$(printf '%s\n' "${IP_ADDRS[@]}" | jq -R . | jq -s '.')
BATCH_RESULT=$(curl -s -X POST "http://ip-api.com/batch?fields=city,country,status,lat,lon" \
  -H "Content-Type: application/json" \
  -d "$BATCH_JSON")

for i in $(seq 1 $TOTAL); do
  entry=$(echo "$BATCH_RESULT" | jq -r ".[$((i-1))]")
  geo_status=$(echo "$entry" | jq -r '.status')
  if [[ "$geo_status" == "success" ]]; then
    GEOS[$i]=$(echo "$entry" | jq -r '"\(.city), \(.country)"')
    LATS[$i]=$(echo "$entry" | jq -r '.lat')
    LONS[$i]=$(echo "$entry" | jq -r '.lon')
  else
    GEOS[$i]="-"
    LATS[$i]=""
    LONS[$i]=""
  fi
done

# ─── Write peer coords ────────────────────────────────────────────────────────

for i in $(seq 1 $TOTAL); do
  lat="${LATS[$i]}"
  lon="${LONS[$i]}"
  geo="${GEOS[$i]}"
  if [[ -n "$lat" && "$lat" != "-" && -n "$lon" && "$lon" != "-" ]]; then
    echo "${lat}|${lon}|${geo}" >> "$PEER_TMP"
  fi
done

# ─── Build full output and pipe to less ──────────────────────────────────────

{
  render_top "$NETINFO_FILE" "$PEER_TMP"
  echo ""
  header "=== Peer Summary ==="
  echo "$PEERINFO" | jq -r '
    .result |
    "Total peers: \(length)",
    "Inbound:     \([.[] | select(.inbound == true)] | length)",
    "Outbound:    \([.[] | select(.inbound == false)] | length)"'
  echo ""
  header "=== Peer List ==="
  { echo "ADDRESS|CLIENT|TYPE|PING|BLOCKS|LOCATION";
    for i in $(seq 1 $TOTAL); do
      echo "${PEERS[$i]}|${GEOS[$i]}"
    done; } | column -t -s '|' | while IFS= read -r line; do
    colorize_row "$line"
  done
} | less -R

rm -f "$NETINFO_FILE" "$PEER_TMP"
