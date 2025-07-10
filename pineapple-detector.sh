#!/bin/bash
source /usr/local/bin/whitelist.sh
source /usr/local/bin/whitelist.sh
##############################################################################
# 🐱🍍  Pineapple-Detector  “Pineapple Chaser”  v8.2-full                     #
#   ▸ Random MAC, airodump CSV, 0-100 heuristics (clamped)                   #
#   ▸ Hak-5 OUIs + user watch-list ⇒ +100 → instant 🚩                       #
#   ▸ Auto-pop-up HTML dashboard (mini HTTP) with Copy/CSV/Excel/PDF/Print   #
#   ▸ Optional wifite counter-attack (`--attack`)                            #
##############################################################################
# Usage                                                                      #
#   sudo ./pineapple-detector.sh [--interface wlanX] [--attack] [--no-open]  #
##############################################################################

############################  USER SETTINGS  ################################
IFACE="wlan1"          # falls back to wlan0 if missing
MON="${IFACE}mon"

LOGDIR="/opt/pineapple-detector/logs"
REPORTDIR="/opt/pineapple-detector/reports"
DASHDIR="/var/www/html/pineapple-detector"

OUI_DB="/usr/share/ieee-data/oui.txt"       # ieee-oui package
WATCHLIST="/opt/pineapple-detector/watchlist.txt"

SCAN_SECS=25          # seconds to capture

# 0-100 scoring weights
HI_PWR=-30            # dBm louder (numeric >) than this
P_OPEN=40  P_PWR=30  P_VEND=20  P_CLONE=20
S_WATCH=100  S_CHHOP=40  S_MGTFLOOD=20
THRESH=60             # ≥ → 🚩 Rogue

# Known Wi-Fi Pineapple OUIs
PINE_OUIS=(00-13-37 AC-86-74 60-64-05)

POPUP=1      # auto-open dashboard
ATTACK=0     # wifite off by default
##############################################################################

######################  SEED WATCH-LIST IF EMPTY  ###########################
if [[ ! -s $WATCHLIST ]]; then
  sudo mkdir -p "$(dirname "$WATCHLIST")"
  sudo tee "$WATCHLIST" >/dev/null <<'WL'
:Pineapple_
:OpenWrt
WL
  sudo chmod 644 "$WATCHLIST"
fi


############################  BANNER  ################################
banner() {
cat <<EOF
[1;37m────────────────────────────────────────────────────────────[0m
    
  ____  ___ _   _ _____    _    ____  ____  _     _____ 
 |  _ \|_ _| \ | | ____|  / \  |  _ \|  _ \| |   | ____|
 | |_) || ||  \| |  _|   / _ \ | |_) | |_) | |   |  _|  
 |  __/ | || |\  | |___ / ___ \|  __/|  __/| |___| |___ 
 |_|   |___|_| \_|_____/_/   \_\_|   |_|   |_____|_____|
 
[1;33m────────────────────────────────────────────────────────────[0m
	   ____ _   _    _    ____  _____ ____  
	  / ___| | | |  / \  / ___|| ____|  _ \ 
	 | |   | |_| | / _ \ \___ \|  _| | |_) |
	 | |___|  _  |/ ___ \ ___) | |___|  _ < 
	  \____|_| |_/_/   \_\____/|_____|_| \_\'
  
[1;37m────────────────────────────────────────────────────────────[0m
    
           😼  Orange Tabby ChubbyCat Activated  😼
[0;33m                |\\_____/|
               /  o   o  \\
[1;37m              (  ==  ^  == )
[0;33m                )         (
              (           )
             ( (  )___(  ) )
            (__(__)___(__)__)
      
[1;37m────────────────────────────────────────────────────────────[0m
[0;33m Interface     : $IFACE
 Monitor Intf. : $MON
 Logs Dir      : $LOGDIR
 Reports Dir   : $REPORTDIR
 Dashboard Dir : $DASHDIR[0m
[1;32m────────────────────────────────────────────────────────────[0m
EOF
}

############################  MAC Whitelist  ################################
source /usr/local/bin/whitelist.sh

echo "Starting Pineapple Detector..."

# Example loop simulating MAC processing
for mac in $(cat /tmp/detected_macs.txt); do
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    if is_mac_whitelisted "$mac"; then
        echo "Whitelisted MAC: $mac"
        continue
    fi

        if is_mac_whitelisted "$mac"; then
            echo "Skipping whitelisted MAC $mac"
            continue
        fi
        echo "Detected potential rogue MAC: $mac"
    fi
done


############################  FLAG PARSING  ################################
while [[ $1 ]]; do
  case $1 in
    --interface) IFACE="$2"; MON="${2}mon"; shift ;;
    --attack)    ATTACK=1   ;;
    --no-open)   POPUP=0    ;;
    -h|--help)
      echo "sudo $0 [--interface wlanX] [--attack] [--no-open]"; exit 0 ;;
    *) echo "unknown flag $1"; exit 1 ;;
  esac; shift
done

############################  DEPENDENCIES  ################################
for b in airmon-ng airodump-ng macchanger python3; do
  command -v "$b" >/dev/null || { echo "❌ need $b"; exit 1; }
done
(( ATTACK )) && command -v wifite >/dev/null || { (( ATTACK )) && { echo "❌ need wifite"; exit 1; }; }

############################  ADAPTER + RANDOM MAC #########################
iw dev "$IFACE" info &>/dev/null || { echo "⚠️  $IFACE absent → wlan0"; IFACE="wlan0"; MON="${IFACE}mon"; }
iw dev "$IFACE" info &>/dev/null || { echo "❌ no wifi adapter"; exit 1; }

sudo ifconfig "$IFACE" down
MACINFO=$(sudo macchanger -r "$IFACE")
sudo ifconfig "$IFACE" up
banner; echo "$MACINFO" | grep -E 'Permanent|Current|New'

#####################  POP-UP & CLEAN-UP HANDLERS  #########################
HTTP_PID=""
open_dash(){
  (( POPUP )) || return
  [[ $HTTP_PID ]] && url="http://localhost:$PORT/$DATE/dashboard.html" || url="file://$HTML_ABS"
  gui=$(loginctl list-sessions --no-legend | awk '$3=="seat0"{print $2;exit}') || gui=$SUDO_USER
  sudo -u "${gui:-$USER}" setsid xdg-open "$url" >/dev/null 2>&1 &
}
trap 'sudo airmon-ng stop "$MON" &>/dev/null; [[ $HTTP_PID ]] && kill $HTTP_PID; open_dash' EXIT INT TERM

############################  DIRECTORIES  #################################
DATE=$(date +%F_%H-%M-%S)
SESSION="$DASHDIR/$DATE"
RAW="$LOGDIR/scan_$DATE"; RAWCSV="$RAW-01.csv"
CSV="$REPORTDIR/report_$DATE.csv"
mkdir -p "$SESSION" "$LOGDIR" "$REPORTDIR" "$DASHDIR"

############################  CAPTURE  ######################################
sudo airmon-ng start "$IFACE" &>/dev/null; sleep 1
sudo timeout "$SCAN_SECS" airodump-ng -w "$RAW" --output-format csv "$MON" 2>/dev/null
RAWCSV=$(ls -t "$RAW"-01.csv | head -1) || { echo "capture failed"; exit 1; }
sudo airmon-ng stop "$MON" &>/dev/null

############################  SCORING  ######################################
echo "BSSID,SSID,Ch,Pwr,Dist,Enc,Manufacturer,Status,Score" >"$CSV"
declare -A CNT CHSEEN SSIDCOUNT
awk -F, 'NR>1&&/^[0-9A-Fa-f:]{17}/ {s=$14;gsub(/^ +| +$/,"",s); if(s&&!/<length/)print s}' "$RAWCSV" |
  while read -r s; do (( CNT[$s]++ )); done
ROG=/tmp/rogues_$DATE; >"$ROG"

while IFS=, read -r bssid _; do
  [[ ! $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && continue
  line=$(grep -m1 "^$bssid" "$RAWCSV")
  ssid=$(echo "$line"|awk -F, '{s=$14;gsub(/^ +| +$/,"",s);print s}'); [[ -z $ssid ]] && continue
  (( SSIDCOUNT[$bssid]++ ))
  ch=$(echo "$line"|cut -d, -f4)
  pwr=$(echo "$line"|cut -d, -f9)
  dist=$(( ( -pwr - 30 ) / 2 )); (( dist<0 )) && dist=0
  enc=$(echo "$line"|cut -d, -f6)
  oui=$(echo "$bssid"|cut -d: -f1-3|tr a-f A-F|sed 's/:/-/g')
  man=$(awk -vO=$oui 'toupper($1)==O{sub(/.*\(hex\)[[:space:]]+/,"");print;exit}' "$OUI_DB"); man=${man//,/ }
  [[ -z $man ]] && man="Unknown"

  score=0; status="✅ Safe"
  [[ $enc =~ (OPN|WEP) ]] && { (( score+=P_OPEN )); status="⚠️ Open"; }
  (( pwr > HI_PWR ))        && (( score+=P_PWR ))
  [[ $man == Unknown ]]     && (( score+=P_VEND ))
  (( CNT[$ssid] > 3 ))      && (( score+=P_CLONE ))

  if grep -qi "^$oui$" "$WATCHLIST" || grep -Eqi "^:.*${ssid}.*" "$WATCHLIST" || \
     printf '%s\n' "${PINE_OUIS[@]}" | grep -qx "$oui"; then (( score+=S_WATCH )); fi

  CHSEEN["$bssid,$ch"]=1
  (( $(grep -c "^$bssid," <<<"${!CHSEEN[*]}") > 2 )) && (( score+=S_CHHOP ))
  (( SSIDCOUNT[$bssid] > 30 )) && (( score+=S_MGTFLOOD ))

  (( score > 100 )) && score=100   # clamp to 0-100

  (( score >= THRESH )) && { status="🚩 Rogue"; echo "$bssid" >>"$ROG"; }
  echo "$bssid,$ssid,$ch,$pwr,$dist,$enc,$man,$status,$score" >>"$CSV"
done < <(awk -F, 'NR>1{print $1}' "$RAWCSV")

TOTAL=$(( $(wc -l <"$CSV") - 1 ))
SAFE=$(grep -c "✅ Safe" "$CSV")
ROGUE=$(grep -c "🚩 Rogue" "$CSV")
OPEN=$(grep -c "⚠️ Open" "$CSV")

############################  OPTIONAL WIFITE  ##############################
if (( ATTACK && ROGUE > 0 )); then
  echo "⚔️  wifite attacking rogues…"
  sudo wifite -b "$(paste -sd, "$ROG")" -mac -p -v
fi

############################  DASHBOARD  ####################################
HTML="$SESSION/dashboard.html"
{
cat <<HTML_HEAD
<!doctype html><html><head><meta charset="utf-8">
<title>Pineapple $DATE</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap5.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.bootstrap5.min.css">
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.bootstrap5.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/pdfmake.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/vfs_fonts.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
</head><body class="container py-4">
<h1>🐱🍍 Pineapple Dashboard</h1><p><small>$DATE UTC</small></p>
<table class="table table-bordered text-center w-auto mb-4"><thead class="table-dark">
<tr><th>Total</th><th>✅ Safe</th><th>🚩 Rogue</th><th>⚠️ Open</th></tr></thead>
<tbody><tr><td>$TOTAL</td><td>$SAFE</td><td>$ROGUE</td><td>$OPEN</td></tr></tbody></table>
<input id="search" class="form-control mb-3" placeholder="Search…">
<table id="tbl" class="table table-striped table-hover" style="width:100%">
<thead class="table-light"><tr>
<th>BSSID</th><th>SSID</th><th>Ch</th><th>Pwr</th><th>Dist</th><th>Enc</th>
<th>Manufacturer</th><th>Status</th><th>Score</th></tr></thead><tbody>
HTML_HEAD

tail -n +2 "$CSV" |
while IFS=',' read -r bssid ssid ch pwr dist enc man status score; do
  printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' \
    "$bssid" "${ssid//&/&amp;}" "$ch" "$pwr" "$dist" "$enc" "${man//&/&amp;}" "$status" "$score"
done

cat <<'HTML_TAIL'
</tbody></table>
<script>
$(function(){
  const dt=$('#tbl').DataTable({
    pageLength:25,
    order:[[8,'desc']],
    dom:'Blfrtip',                // Buttons + length + filter + table + info + pagination
    buttons:['copy','csv','excel','pdf','print']
  });
  $('#search').on('keyup', e=>dt.search(e.target.value).draw());
});
</script></body></html>
HTML_TAIL
} >"$HTML"

HTML_ABS=$(realpath "$HTML")
ln -sfn "$SESSION" "$DASHDIR/latest"

############################  MINI HTTP  ####################################
if (( POPUP )); then
  PORT=$(shuf -i 2000-65000 -n 1)
  cd "$DASHDIR" && python3 -m http.server "$PORT" >/dev/null 2>&1 &
  HTTP_PID=$!
fi

echo "Dashboard saved → $HTML_ABS"
