#!/bin/bash

# ============================================================
# ADVANCED RECON & DNS ENUMERATION FRAMEWORK
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

THREADS=50
WORDLIST="/usr/share/seclists/Discovery/Web-Content/common.txt"
SILENT=false
PASSIVE=false
FULL=false
INTERACTIVE=false

banner() {

clear

echo -e "${BLUE}"
cat << "EOF"
 ____  _____ ____ ___  _   _
|  _ \| ____/ ___/ _ \| \ | |
| |_) |  _|| |  | | | |  \| |
|  _ <| |__| |__| |_| | |\  |
|_| \_\_____\____\___/|_| \_|

EOF
echo -e "${NC}"

echo -e "${BLUE}======================================================="
echo -e "        ADVANCED RECON AUTOMATION FRAMEWORK"
echo -e "=======================================================${NC}"
echo

if [ "$SILENT" = false ]; then
    loading_animation "Initializing framework"
fi

}

loading_animation() {

local msg="$1"
local dots=("." ".." "..." "....")

for i in {1..2}; do
    for d in "${dots[@]}"; do
        printf "\r${GREEN}[+] %s%-4s${NC}" "$msg" "$d"
        sleep 0.2
    done
done

printf "\r${GREEN}[+] %s... Done${NC}\n\n" "$msg"

}

spinner() {

local pid=$1
local msg="$2"
local spin='|/-\'
local i=0

while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r${YELLOW}[*] %s %s${NC}" "$msg" "${spin:$i:1}"
    sleep 0.1
done

printf "\r${GREEN}[+] %s Done${NC}\n" "$msg"

}

interactive_setup() {

echo -e "${YELLOW}======================================================="
echo "               INTERACTIVE SETUP"
echo -e "=======================================================${NC}"
echo

while [ -z "$DOMAIN" ]; do
    read -e -p "Target Domain (e.g. example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}[x] Domain cannot be empty.${NC}"
    fi
done

read -e -p "Output Directory [recon-$DOMAIN]: " INPUT_OUTPUT
OUTPUT=${INPUT_OUTPUT:-recon-$DOMAIN}

read -e -p "Threads [$THREADS]: " INPUT_THREADS
THREADS=${INPUT_THREADS:-$THREADS}

read -e -p "Custom Wordlist [$WORDLIST]: " INPUT_WORDLIST
WORDLIST=${INPUT_WORDLIST:-$WORDLIST}

read -e -p "Silent Mode? (y/N): " INPUT_SILENT
if [[ "$INPUT_SILENT" =~ ^[Yy]$ ]]; then
    SILENT=true
fi

echo

}

start_menu() {

echo -e "${YELLOW}======================================================="
echo "                  SELECT SCAN MODE"
echo -e "=======================================================${NC}"
echo "  1) Quick Scan   (Passive recon only)"
echo "  2) Full Scan    (Passive + Crawling + Fuzzing)"
echo "  3) Continue with current settings"
echo "  4) Help Menu"
echo "  5) Exit"
echo

read -e -p "Select an option [1-5]: " CHOICE

case $CHOICE in
    1) FULL=false; PASSIVE=true ;;
    2) FULL=true; PASSIVE=false ;;
    3) : ;;
    4) help_menu ;;
    5)
        echo -e "${YELLOW}[!] Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[x] Invalid option.${NC}"
        exit 1
        ;;
esac

echo

}

help_menu() {

echo "Usage:"
echo "  ./final.sh                          (interactive mode — no flags needed)"
echo "  ./final.sh -d domain.com [OPTIONS]   (direct mode — for automation)"
echo
echo "Options (all optional — omit them to run interactively):"
echo "  -d    Target Domain"
echo "  -o    Output Directory"
echo "  -t    Threads"
echo "  -w    Custom Wordlist"
echo "  -s    Silent Mode"
echo "  -p    Passive Recon Only (skips reverse lookup, WAF/fingerprint/headers/SSL checks)"
echo "  -f    Full Scan Mode (adds crawling and fuzzing)"
echo "  -h    Show Help Menu"
echo
exit 1

}

while getopts "d:o:t:w:spfh" opt; do
  case $opt in
    d) DOMAIN=$OPTARG ;;
    o) OUTPUT=$OPTARG ;;
    t) THREADS=$OPTARG ;;
    w) WORDLIST=$OPTARG ;;
    s) SILENT=true ;;
    p) PASSIVE=true ;;
    f) FULL=true ;;
    h) help_menu ;;
    *) help_menu ;;
  esac
done

if [ -z "$DOMAIN" ]; then
    INTERACTIVE=true
fi

banner

if [ "$INTERACTIVE" = true ]; then
    interactive_setup
    start_menu
else
    OUTPUT=${OUTPUT:-recon-$DOMAIN}
fi

mkdir -p $OUTPUT

log() {

if [ "$SILENT" = false ]; then
    echo -e "${GREEN}[+] $1${NC}"
fi

}

TOOLS=(
dig
host
nslookup
whois
curl
subfinder
assetfinder
findomain
dnsx
httpx
whatweb
wafw00f
ffuf
gau
katana
sslscan
)

check_dependencies() {

for tool in "${TOOLS[@]}"
do
    if ! command -v $tool &> /dev/null
    then
        echo "[!] $tool not installed"
    fi
done

}

whois_enum() {

log "Running WHOIS Enumeration"

whois $DOMAIN > $OUTPUT/whois.txt

}

dns_records() {

log "Enumerating DNS Records"

RECORDS=(
A
AAAA
MX
NS
TXT
SOA
CNAME
CAA
SRV
ANY
)

for record in "${RECORDS[@]}"
do

    dig $DOMAIN $record \
    > $OUTPUT/$record.txt

done

}

resolver_testing() {

RESOLVERS=(
1.1.1.1
8.8.8.8
9.9.9.9
)

for resolver in "${RESOLVERS[@]}"
do

    dig @$resolver $DOMAIN \
    > $OUTPUT/resolver-$resolver.txt

done

}

dns_trace() {

dig +trace $DOMAIN \
> $OUTPUT/dns-trace.txt

}

reverse_lookup() {

IPS=$(dig +short $DOMAIN | grep -E '^[0-9.]+$')

for ip in $IPS
do

    dig -x $ip \
    >> $OUTPUT/reverse-dns.txt

done

}

subdomain_enum() {

subfinder -d $DOMAIN -silent \
> $OUTPUT/subfinder.txt

assetfinder --subs-only $DOMAIN \
> $OUTPUT/assetfinder.txt

findomain -t $DOMAIN -q \
> $OUTPUT/findomain.txt

cat \
$OUTPUT/subfinder.txt \
$OUTPUT/assetfinder.txt \
$OUTPUT/findomain.txt \
| sort -u \
> $OUTPUT/all-subdomains.txt

}

resolve_hosts() {

dnsx \
-l $OUTPUT/all-subdomains.txt \
-a -resp \
-nc \
> $OUTPUT/live-hosts.txt

}

http_probe() {

httpx \
-l $OUTPUT/all-subdomains.txt \
-tech-detect \
-title \
-status-code \
-follow-redirects \
-server \
-ip \
-cdn \
-no-color \
-threads $THREADS \
> $OUTPUT/httpx.txt

}

waf_detection() {

wafw00f https://$DOMAIN \
--no-colors \
> $OUTPUT/waf.txt

}

fingerprinting() {

whatweb https://$DOMAIN \
-v \
--color=never \
> $OUTPUT/whatweb.txt

}

security_headers() {

curl -I -s https://$DOMAIN \
> $OUTPUT/security-headers.txt

}

ssl_analysis() {

sslscan --no-colour $DOMAIN \
> $OUTPUT/sslscan.txt

}

historical_urls() {

log "Fetching Historical URLs (gau)"

if [ -s "$OUTPUT/all-subdomains.txt" ]; then
    gau \
    --threads $THREADS \
    --subs \
    < $OUTPUT/all-subdomains.txt \
    | sort -u \
    > $OUTPUT/gau.txt
else
    gau \
    --threads $THREADS \
    --subs \
    $DOMAIN \
    | sort -u \
    > $OUTPUT/gau.txt
fi

log "Historical URLs saved: $(wc -l < $OUTPUT/gau.txt 2>/dev/null || echo 0) URLs"

}

katana_crawl() {

katana \
-u https://$DOMAIN \
-jc \
-nc \
> $OUTPUT/katana.txt

}

directory_enum() {

ffuf \
-u https://$DOMAIN/FUZZ \
-w $WORDLIST \
-mc 200,204,301,302,307,401,403,405,500 \
-t $THREADS \
-noninteractive \
> $OUTPUT/ffuf.txt

}

summary() {

echo "RECON SUMMARY" \
> $OUTPUT/summary.txt

cat $OUTPUT/httpx.txt \
>> $OUTPUT/summary.txt

}

check_dependencies

whois_enum
dns_records
resolver_testing
dns_trace
subdomain_enum
resolve_hosts
http_probe
historical_urls

if [ "$PASSIVE" = false ]; then

    reverse_lookup
    waf_detection
    fingerprinting
    security_headers
    ssl_analysis

else

    log "Passive mode enabled — skipping active probes (reverse lookup, WAF/fingerprint/headers/SSL checks)"

fi

if [ "$FULL" = true ]; then

    katana_crawl
    directory_enum

fi

summary

echo
echo -e "${GREEN}[+] Recon Completed Successfully${NC}"
echo -e "${GREEN}[+] Results Saved in: $OUTPUT/${NC}"
