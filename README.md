# recon.sh

a simple bash script that automates the boring parts of recon during pentesting. basically it chains together a bunch of tools i use all the time (subfinder, httpx, nmap, nuclei, etc.) so i dont have to run them one by one manually.

i built this because i got tired of typing the same commands over and over during bug bounty / pentest engagements. its not fancy, it just works.

---

## what it does

give it a domain, and it'll:

1. **find subdomains** — uses subfinder + assetfinder to pull subdomains, deduplicates them
2. **check whats alive** — resolves DNS with dnsx, then probes HTTP with httpx to find live websites
3. **fingerprint tech** — runs whatweb to figure out what tech stack each site is using
4. **port scan** — runs nmap with service detection on the main domain
5. **take screenshots** — uses gowitness to screenshot every live site (useful for quickly eyeballing whats running)
6. **scan for vulns** — runs nuclei templates (CVEs + known vulns) against all live targets
7. **crawl urls** — uses katana + gau to crawl and collect URLs, then greps for interesting patterns (xss, sqli params, exposed secrets like .env files, api keys, etc.)
8. **directory bruteforce** — runs feroxbuster on the top 5 targets with a common wordlist

everything runs in parallel so it doesnt take forever. theres a live dashboard in the terminal that shows you which tasks are done and which are still running, with a countdown timer.

at the end it drops a `summary_report.txt` with the numbers — how many subdomains, live sites, open ports, vulns, and potential secrets it found.

---

## output structure

```
domain.com/
├── subdomains/
│   ├── found.txt          # raw subdomain results
│   ├── subs.txt           # deduplicated subdomains
│   ├── dns.txt            # DNS resolution results
│   └── live_dns.txt       # subdomains that resolved
├── web/
│   ├── httpx.txt          # HTTP probe results (status codes, titles)
│   ├── targets.txt        # clean list of live URLs
│   ├── crawl.txt          # raw crawled URLs
│   ├── urls.txt           # deduplicated URLs
│   └── dirs.txt           # directory bruteforce results
├── nmap/
│   ├── scan.nmap          # nmap output (normal)
│   ├── scan.xml           # nmap output (xml)
│   └── scan.gnmap         # nmap output (grepable)
├── vulns/
│   ├── nuclei.txt         # vulnerability scan results
│   ├── xss.txt            # URLs with potential XSS params
│   └── sqli.txt           # URLs with potential SQLi params
├── tech/
│   └── tech.txt           # technology fingerprints
├── screens/               # screenshots of live sites
├── secrets/
│   └── potential_leaks.txt  # URLs with exposed configs/keys
└── summary_report.txt     # final summary
```

---

## requirements

you need **Kali Linux** or any debian-based distro. the script checks for the important tools before running and will yell at you if something is missing.

### tools used

| Tool | What its for | Install |
|------|-------------|---------|
| subfinder | subdomain enumeration | `go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest` |
| assetfinder | more subdomain sources | `go install github.com/tomnomnom/assetfinder@latest` |
| dnsx | DNS resolution | `go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest` |
| httpx | HTTP probing | `go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest` |
| nmap | port scanning | `sudo apt install nmap` |
| whatweb | tech fingerprinting | `sudo apt install whatweb` |
| gowitness | screenshots | `go install github.com/sensepost/gowitness@latest` |
| nuclei | vulnerability scanning | `go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest` |
| katana | web crawling | `go install github.com/projectdiscovery/katana/cmd/katana@latest` |
| gau | fetch known URLs | `go install github.com/lc/gau/v2/cmd/gau@latest` |
| gf | grep for patterns | `go install github.com/tomnomnom/gf@latest` |
| feroxbuster | directory bruteforce | `sudo apt install feroxbuster` or check [github](https://github.com/epi052/feroxbuster) |

---

## full install guide

most of these tools are written in Go, so you need Go installed first. the easiest way to get Go (and fix a bunch of other stuff on kali at the same time) is **pimpmykali**.

### step 1 — install Go using pimpmykali

if you dont have Go installed or your kali is acting weird (missing tools, broken paths, etc.), just run pimpmykali. it fixes a ton of common kali issues and installs Go properly for you.

```bash
cd /opt
sudo git clone https://github.com/Dewalt-arch/pimpmykali.git
cd pimpmykali
sudo ./pimpmykali.sh
```

when it opens the menu, you can either:
- pick the option to **fix everything** (recommended if its a fresh kali install)
- or just pick the option that **installs Go** if thats all you need

after its done, **close your terminal and open a new one** so the paths load properly. then verify Go is working:

```bash
go version
```

if that prints a version number, youre good to move on.

> **note:** if you already have Go installed and working, you can skip pimpmykali entirely. but honestly if youre on a fresh kali VM or stuff is broken, pimpmykali saves a lot of headache. just use it.

also make sure your Go bin path is set up so you can actually run the tools after installing them. add this to your `~/.bashrc` or `~/.zshrc`:

```bash
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin
```

then reload it:

```bash
source ~/.bashrc
```

### step 2 — install apt packages

these are the tools that come from apt, not Go:

```bash
sudo apt update
sudo apt install -y nmap whatweb feroxbuster
```

### step 3 — install all the Go tools

now install all the Go-based tools. just copy paste this whole block into your terminal:

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/assetfinder@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/sensepost/gowitness@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/gf@latest
```

this will take a few minutes depending on your internet. each tool gets downloaded, compiled, and dropped into your `$GOPATH/bin` folder.

### step 4 — setup gf patterns

gf is useless without pattern files. it needs json files that tell it what to grep for (xss params, sqli params, etc.). grab a community pattern pack:

```bash
mkdir -p ~/.gf
git clone https://github.com/1ndianl33t/Gf-Patterns.git
cp Gf-Patterns/*.json ~/.gf/
rm -rf Gf-Patterns
```

### step 5 — update nuclei templates

nuclei needs its template library to actually scan for anything. run this once to pull them down:

```bash
nuclei -update-templates
```

it downloads thousands of detection templates (CVEs, misconfigs, exposures, etc.) from the nuclei-templates repo.

### step 6 — verify everything works

quick sanity check — run these and make sure none of them say "command not found":

```bash
subfinder -version
httpx -version
nmap --version
nuclei -version
katana -version
dnsx -version
gau -version
gowitness version
feroxbuster --version
whatweb --version
gf -h
assetfinder -h
```

if any of them are missing, its probably a PATH issue. go back to step 1 and make sure `$GOPATH/bin` is in your PATH.

---

## how to run

```bash
# clone the repo
git clone https://github.com/YOUR_USERNAME/recon.sh.git
cd recon.sh

# make it executable
chmod +x recon.sh

# run it (needs sudo for nmap)
sudo ./recon.sh target.com
```

replace `target.com` with whatever domain you have permission to test. the script creates a folder named after the domain in your current directory and dumps all the output there.

---

## things to know

- needs **sudo** — nmap needs root for SYN scans and gowitness needs `--no-sandbox` when running as root
- needs **internet** — the script pings 8.8.8.8 before starting to make sure youre connected
- runs scans **in parallel** so its way faster than running everything one by one
- the live dashboard in the terminal shows progress for each module with a countdown timer
- directory bruteforce only hits the **top 5 targets** to keep scan time reasonable. you can change that number in the script if you want more
- uses `/usr/share/wordlists/dirb/common.txt` by default. edit the `WORDLIST` variable at the top of the script to use a different wordlist
- parallel tasks are capped at **15 minutes** timeout so it doesnt hang forever on huge scopes
- after the scan finishes, file permissions get fixed automatically so your normal (non-root) user can access and delete the output folder

---

## disclaimer

this is for **authorized testing only**. dont run this against targets you dont have written permission to test. im not responsible for how anyone uses this tool. always get proper authorization before scanning anything.

---

## todo / ideas

- [ ] add slack/discord webhook notifications when scan finishes
- [ ] generate an html report instead of plain text
- [ ] add flags to skip specific modules
- [ ] support for scanning IP ranges, not just domains
- [ ] option to use custom nuclei template folders

---

if you found this useful or want to suggest something, open an issue or send a PR.
