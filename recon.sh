#!/bin/bash

# Recon Automation
# Usage: sudo ./recon.sh domain.com

DOMAIN=$1
DIR=$(pwd)/$DOMAIN
WORDLIST="/usr/share/wordlists/dirb/common.txt"

# Colors
NC='\033[0m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'

# Need root for nmap/permissions
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run with sudo.${NC}"
  exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo "Usage: sudo ./recon.sh <domain.com>"
    exit 1
fi

# Check if tools are installed
echo -e "${YELLOW}[*] Checking tools...${NC}"

ping -c 1 8.8.8.8 >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}[!] No internet.${NC}"
    exit 1
fi

for tool in subfinder httpx nmap nuclei; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}[!] Missing tool: $tool${NC}"
        exit 1
    fi
done

# Setup folders
clear
echo -e "${BLUE}Target: $DOMAIN${NC}"
echo -e "${BLUE}Output: $DIR${NC}"
echo ""

mkdir -p $DIR/{subdomains,nmap,web,vulns,screens,tech,secrets}

# ---------------------------------------------
# Discovery
# ---------------------------------------------

echo -e "${YELLOW}[*] Gathering subdomains...${NC}"
timeout 2m subfinder -d $DOMAIN -silent -nc > $DIR/subdomains/found.txt 2>/dev/null
timeout 2m assetfinder $DOMAIN | grep $DOMAIN >> $DIR/subdomains/found.txt 2>/dev/null
sort -u $DIR/subdomains/found.txt > $DIR/subdomains/subs.txt
count=$(wc -l < $DIR/subdomains/subs.txt)
echo -e "${GREEN}    -> Found $count subdomains.${NC}"

echo -e "${YELLOW}[*] Finding live hosts...${NC}"
# Resolving
cat $DIR/subdomains/subs.txt | dnsx -silent -a -resp -nc -o $DIR/subdomains/dns.txt 2>/dev/null
cat $DIR/subdomains/dns.txt | awk '{print $1}' > $DIR/subdomains/live_dns.txt

# HTTP probing
cat $DIR/subdomains/live_dns.txt | httpx -silent -sc -title -nc -threads 50 -timeout 5 -o $DIR/web/httpx.txt 2>/dev/null
cat $DIR/web/httpx.txt | awk '{print $1}' > $DIR/web/targets.txt

alive=$(wc -l < $DIR/web/targets.txt)
echo -e "${GREEN}    -> Found $alive live sites.${NC}"

if [ "$alive" -eq 0 ]; then
    echo -e "${RED}[!] No targets found. Exiting.${NC}"
    echo "Check internet or domain name." > $DIR/README_ERROR.txt
    exit 1
fi

echo -e "${YELLOW}[*] Fingerprinting...${NC}"
whatweb -i $DIR/web/targets.txt --color=never --no-errors --log-brief=$DIR/tech/tech.txt >/dev/null 2>&1

# ---------------------------------------------
# Active Scans
# ---------------------------------------------

# Quick time calc (approx 5s per host)
est_time=$((alive * 5 + 60))
[ $est_time -gt 900 ] && est_time=900 # Cap at 15m

echo ""
echo -e "${YELLOW}[*] Running scans in background...${NC}"
echo -e "${BLUE}    Est. time: $(($est_time / 60)) mins${NC}"

# Nmap
(
    timeout $(($est_time + 300))s nmap -sC -sV -T4 --min-rate 1000 --open $DOMAIN -oA $DIR/nmap/scan >/dev/null 2>&1
    touch $DIR/.nmap
) &
PID1=$!

# Screenshots
(
    # Needs special flags for root
    timeout $(($est_time + 60))s gowitness scan file -f $DIR/web/targets.txt --threads 10 --write-db=false --screenshot-path $DIR/screens/ --no-http --chrome-args='--no-sandbox --disable-gpu' >/dev/null 2>&1
    
    # Fallback check
    if [ -z "$(ls -A $DIR/screens/ 2>/dev/null)" ]; then
         timeout $(($est_time + 60))s gowitness file -f $DIR/web/targets.txt --threads 10 -P $DIR/screens/ --no-http --timeout 10 >/dev/null 2>&1
    fi
    touch $DIR/.screens
) &
PID2=$!

# Nuclei
(
    timeout $(($est_time + 60))s nuclei -l $DIR/web/targets.txt -t cves -t vulnerabilities -silent -nc -c 50 -mhe 10 -o $DIR/vulns/nuclei.txt >/dev/null 2>&1
    touch $DIR/.nuclei
) &
PID3=$!

# Crawling + Secrets
(
    timeout $(($est_time + 60))s katana -list $DIR/web/targets.txt -jc -kf all -silent -nc -c 20 -o $DIR/web/crawl.txt 2>/dev/null
    cat $DIR/subdomains/live_dns.txt | gau --subs $DOMAIN >> $DIR/web/crawl.txt 2>/dev/null
    sort -u $DIR/web/crawl.txt > $DIR/web/urls.txt
    
    # Grep for bugs
    gf xss $DIR/web/urls.txt > $DIR/vulns/xss.txt 2>/dev/null
    gf sqli $DIR/web/urls.txt > $DIR/vulns/sqli.txt 2>/dev/null
    
    # Grep for secrets
    grep -E "\.env|\.config|\.git/|api_key|password|secret" $DIR/web/urls.txt > $DIR/secrets/potential_leaks.txt 2>/dev/null
    
    touch $DIR/.crawl
) &
PID4=$!

# Dir Brute
(
    head -n 5 $DIR/web/targets.txt > $DIR/web/ferox_targets.txt
    if [ -s "$DIR/web/ferox_targets.txt" ]; then
        feroxbuster --stdin --parallel 2 -w $WORDLIST -t 50 --depth 1 --extract-links --auto-tune --silent --no-state --time-limit 10m -o $DIR/web/dirs.txt < $DIR/web/ferox_targets.txt >/dev/null 2>&1
    fi
    touch $DIR/.ferox
) &
PID5=$!

# ---------------------------------------------
# Dashboard
# ---------------------------------------------
start=$(date +%s)

echo ""
echo ""
echo ""
echo ""
echo ""
echo ""

while kill -0 $PID1 2>/dev/null || kill -0 $PID2 2>/dev/null || kill -0 $PID3 2>/dev/null || kill -0 $PID4 2>/dev/null || kill -0 $PID5 2>/dev/null; do
    
    now=$(date +%s)
    diff=$((now - start))
    left=$((est_time - diff))
    
    if [ $left -le 0 ]; then
        timer="Finishing..."
    else
        timer=$(printf "%02d:%02d" $((left / 60)) $((left % 60)))
    fi

    [ -f $DIR/.nmap ] && s1="${GREEN}DONE   ${NC}" || s1="${YELLOW}WORKING${NC}"
    [ -f $DIR/.screens ] && s2="${GREEN}DONE   ${NC}" || s2="${YELLOW}WORKING${NC}"
    [ -f $DIR/.nuclei ] && s3="${GREEN}DONE   ${NC}" || s3="${YELLOW}WORKING${NC}"
    [ -f $DIR/.crawl ] && s4="${GREEN}DONE   ${NC}" || s4="${YELLOW}WORKING${NC}"
    [ -f $DIR/.ferox ] && s5="${GREEN}DONE   ${NC}" || s5="${YELLOW}WORKING${NC}"

    echo -ne "\033[6A" 
    echo -e "   Time Left: [ $timer ]   "
    echo -e "   -----------------------"
    echo -e "   Nmap:        $s1"
    echo -e "   Screenshots: $s2"
    echo -e "   Nuclei:      $s3"
    echo -e "   Crawling:    $s4"
    echo -e "   Brute Force: $s5"
    sleep 1
done

rm -f $DIR/.* 2>/dev/null

# ---------------------------------------------
# Summary
# ---------------------------------------------

echo "------------------------------------------------" > $DIR/summary_report.txt
echo "RECON REPORT: $DOMAIN" >> $DIR/summary_report.txt
echo "Date: $(date)" >> $DIR/summary_report.txt
echo "------------------------------------------------" >> $DIR/summary_report.txt
echo "Subdomains:  $(wc -l < $DIR/subdomains/subs.txt)" >> $DIR/summary_report.txt
echo "Live Sites:  $(wc -l < $DIR/web/targets.txt)" >> $DIR/summary_report.txt
echo "Open Ports:  $(grep "open" $DIR/nmap/scan.nmap 2>/dev/null | wc -l)" >> $DIR/summary_report.txt
echo "Vulns Found: $(wc -l < $DIR/vulns/nuclei.txt)" >> $DIR/summary_report.txt
echo "Secrets:     $(wc -l < $DIR/secrets/potential_leaks.txt)" >> $DIR/summary_report.txt
echo "------------------------------------------------" >> $DIR/summary_report.txt

# Fix permissions so regular user can delete
if [ ! -z "$SUDO_USER" ]; then
    chown -R $SUDO_USER:$SUDO_USER $DIR
fi

echo ""
echo -e "${GREEN}[+] Done.${NC}"
echo -e "    Report: $DIR/summary_report.txt"
echo -e "    Folder: $DIR"
