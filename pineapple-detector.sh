#!/bin/bash

##############################################################################
# 🐱🍍  Pineapple-Detector  “Pineapple Chaser”  v8.2-full (MIT, Docker/Alfa)  #
##############################################################################

# ---------- HELP & USAGE ----------
show_help() {
cat <<EOF
──────────────────────────────────────────────
      🐱🍍 Pineapple Chaser WiFi Detector 🍍🐱
──────────────────────────────────────────────
Detects rogue WiFi Access Points (APs), including
WiFi Pineapple/EvilTwin devices, using Alfa AWUS1900,
Docker, or native Linux. Outputs a beautiful dashboard,
auto-scores threats, and flags suspicious/unsafe APs.

USAGE:
  ./pineapple-detector.sh [options]

OPTIONS:
  --interface <iface>  Use specific WiFi interface (default: first wlan*)
  --attack             Run wifite attack mode on rogues (dangerous!)
  --no-open            Do not auto-open dashboard in browser
  -h, --help           Show this help and exit

EXAMPLES:
  sudo ./pineapple-detector.sh --interface wlan1
  sudo ./pineapple-detector.sh -h

KEY FEATURES:
  - ChubbyCat terminal banner (😼)
  - Auto-detects WiFi interfaces (wlan*)
  - Robust CSV parsing & dashboard creation
  - MITM/WiFi Pineapple/EvilTwin heuristics
  - MIT Licensed, open for modification/use

──────────────────────────────────────────────
MIT License - Summary:
  - Free for commercial/private use
  - Modify and redistribute permitted
  - No warranty provided ("as-is")
  - See full license at: https://opensource.org/licenses/MIT
──────────────────────────────────────────────
EOF
exit 0
}

# ----------- Argument Parsing: Show help if -h/--help given -------------
for arg in "$@"; do
  [[ "$arg" == "-h" || "$arg" == "--help" ]] && show_help
done

# =================== INTERFACE AUTODETECT ===========================
if [[ -z "$WIFI_IFACE" ]]; then
  WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | grep '^wlan' | head -1)
  echo "[Auto-detect] Using WiFi interface: $WIFI_IFACE"
fi
IFACE="$WIFI_IFACE"
MON="$IFACE"

LOGDIR="/opt/pineapple-detector/logs"
REPORTDIR="/opt/pineapple-detector/reports"
DASHDIR="/var/www/html/pineapple-detector"
OUI_DB="/usr/share/ieee-data/oui.txt"
WATCHLIST="/opt/pineapple-detector/watchlist.txt"
SCAN_SECS="${SCAN_SECS:-60}"

HI_PWR=-30
P_OPEN=40  P_PWR=30  P_VEND=20  P_CLONE=20
S_WATCH=100  S_CHHOP=40  S_MGTFLOOD=20
THRESH=60
PINE_OUIS=(00-13-37 AC-86-74 60-64-05)
POPUP=1
ATTACK=0

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

###########################  ARGUMENTS  ######################################
while [[ $1 ]]; do
  case $1 in
    --interface) IFACE="$2"; MON="$2"; shift ;;
    --attack)    ATTACK=1   ;;
    --no-open)   POPUP=0    ;;
    -h|--help)
      show_help ;;
    *) echo "unknown flag $1"; exit 1 ;;
  esac; shift
done

banner

###########################  WATCHLIST SEED  #################################
if [[ ! -s $WATCHLIST ]]; then
  mkdir -p "$(dirname "$WATCHLIST")"
  tee "$WATCHLIST" >/dev/null <<'WL'
:Pineapple_
:OpenWrt
WL
  chmod 644 "$WATCHLIST"
fi

#####################  SETUP MONITOR MODE  ###################################
ifconfig "$IFACE" down
iw dev "$IFACE" set type monitor
ifconfig "$IFACE" up
sleep 1

mkdir -p "$LOGDIR" "$REPORTDIR" "$DASHDIR"

DATE=$(date +%F_%H-%M-%S)
RAW="$LOGDIR/scan_$DATE"

###########################  AIRODUMP CAPTURE  ###############################
airodump-ng -w "$RAW" --output-format csv "$MON" &
PID=$!
sleep "$SCAN_SECS"
kill -2 $PID
wait $PID

#######################  STABLE CSV DETECTION  ###############################
for i in {1..10}; do
  RAWCSV=$(ls -t "$LOGDIR"/scan_*-01.csv 2>/dev/null | head -1)
  if [[ -f "$RAWCSV" && $(stat -c%s "$RAWCSV") -gt 1000 ]]; then
    CURSIZE=$(stat -c%s "$RAWCSV")
    sleep 2
    NEWSIZE=$(stat -c%s "$RAWCSV")
    if [[ "$CURSIZE" -eq "$NEWSIZE" ]]; then
      echo "✅ Found and stabilized CSV: $RAWCSV"
      break
    fi
  fi
  echo "[DEBUG] Waiting for a recent CSV to appear..."
  sleep 2
done

if [[ ! -f "$RAWCSV" || $(stat -c%s "$RAWCSV") -lt 1000 ]]; then
  echo "❌ CSV capture incomplete or missing. Check monitor mode or proximity."
  ls -lh "$LOGDIR"
  exit 1
fi

echo "[*] Parsing results from $RAWCSV ..."

######################  ROGUE SCORING + CSV PARSE  ###########################
CSV="$REPORTDIR/report_$DATE.csv"
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

######################  OPTIONAL ATTACK  ####################################
if (( ATTACK && ROGUE > 0 )); then
  echo "⚔️  wifite attacking rogues…"
  wifite -b "$(paste -sd, "$ROG")" -mac -p -v
fi

######################  DASHBOARD GENERATION  ###############################
mkdir -p "$DASHDIR/$DATE"
HTML="$DASHDIR/$DATE/dashboard.html"
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
    dom:'Blfrtip',
    buttons:['copy','csv','excel','pdf','print']
  });
  $('#search').on('keyup', e=>dt.search(e.target.value).draw());
});
</script></body></html>
HTML_TAIL
} >"$HTML"

HTML_ABS=$(realpath "$HTML")
ln -sfn "$DASHDIR/$DATE" "$DASHDIR/latest"

echo "Dashboard saved → $HTML_ABS"

######################  POP-UP DASHBOARD  ###################################
if (( POPUP )); then
  gui=$(loginctl list-sessions --no-legend | awk '$3=="seat0"{print $2;exit}') || gui=$USER
  setsid xdg-open "file://$HTML_ABS" >/dev/null 2>&1 &
fi

exit 0
