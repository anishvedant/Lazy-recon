# Recon.sh

A simple bash script that automates the boring parts of recon during pentesting, basically it chains together a bunch of tools I use all the time (subfinder, httpx, nmap, nuclei, etc.) so i dont have to run them one by one manually.

I built this because I got tired of typing the same commands over and over during bug bounty / pentest engagements. It's not fancy, it just works.

---

## What it does

Give it a domain, and it'll:

1. **find subdomains** — uses subfinder + assetfinder to pull subdomains, deduplicates them
2. **check whats alive** — resolves DNS with dnsx, then probes HTTP with httpx to find live websites
3. **fingerprint tech** — runs whatweb to figure out what tech stack each site is using
4. **port scan** — runs nmap with service detection on the main domain
5. **take screenshots** — uses gowitness to screenshot every live site (useful for quickly eyeballing what's running)
6. **scan for vulns** — runs nuclei templates (CVEs + known vulns) against all live targets
7. **crawl URLs** — uses katana + gau to crawl and collect URLs, then greps for interesting patterns (XSS, SQLI params, exposed secrets like .env files, api keys, etc.)
8. **directory bruteforce** — runs feroxbuster on the top 5 targets with a common wordlist

Everything runs in parallel, so it doesn't take forever. There's a live dashboard in the terminal that shows you which tasks are done and which are still running, with a countdown timer.

At the end, it drops a `summary_report.txt` with the numbers — how many subdomains, live sites, open ports, vulns, and potential secrets it found.

---

## Output structure

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
│   └── dirs.txt           # directory brute-force results
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
## Screenshots

Here is the tool in action during a scan:

**1. Real-Time Dashboard**
The script features a live dashboard that updates every second. It calculates a smart ETA based on the number of subdomains found and shows the current status of every background tool.
![Live dashboard showing the countdown timer and tool progress](Img)

**2. Clean Completion**
Once all tasks are finished, the script automatically cleans up temporary files, fixes folder permissions (so you don't need `sudo` to browse them), and generates a final summary report.
![Script completion screen showing the final status and output directory](Img%202.jpg)


## Requirements

You need **Kali Linux** or any Debian-based distro. The script checks for the important tools before running and will yell at you if something is missing.

### Tools used

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

## Full install guide

Most of these tools are written in Go, so you need Go installed first. The easiest way to get Go (and fix a bunch of other stuff on Kali at the same time) is **pimpmykali**.

### step 1 — install Go using pimpmykali

If you don't have Go installed or your Kali is acting weird (missing tools, broken paths, etc.), just run pimpmykali. It fixes a ton of common Kali issues and installs Go properly for you.

```bash
cd /opt
sudo git clone https://github.com/Dewalt-arch/pimpmykali.git
cd pimpmykali
sudo ./pimpmykali.sh
```

When it opens the menu, you can either:
- pick the option to **fix everything** (recommended if it's a fresh Kali install)
- or just pick the option that **installs Go** if that's all you need

after its done, **close your terminal and open a new one** so the paths load properly. Then verify Go is working:

```bash
go version
```

If that prints a version number, you're good to move on.

> **note:** If you already have Go installed and working, you can skip pimpmykali entirely. But honestly, if you're on a fresh Kali VM or stuff is broken, pimpmykali saves a lot of headache. Just use it.

also make sure your Go bin path is set up so you can actually run the tools after installing them. add this to your `~/.bashrc` or `~/.zshrc`:

```bash
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin
```

Then reload it:

```bash
source ~/.bashrc
```

### step 2 — install apt packages

These are the tools that come from apt, not Go:

```bash
sudo apt update
sudo apt install -y nmap whatweb feroxbuster
```

### step 3 — install all the Go tools

Now install all the Go-based tools. just copy paste this whole block into your terminal:

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmRunubfinder@latest
go install github.com/tomnomnom/assetfinder@latest
goItnstall -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/sensepost/gowitness@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/gf@latest
```

This will take a few minutes, depending on your internet. Each tool gets downloaded, compiled, and dropped into your `$GOPATH/bin` folder.

### step 4 — setup gf patterns

gf is useless without pattern files. It needs JSON files that tell it what to grep for (XSS params, sqli params, etc.). Grab a community pattern pack:

```bash
mkdir -p ~/.gf
git clone https://github.com/1ndianl33t/Gf-Patterns.git
cp Gf-Patterns/*.json ~/.gf/
rm -rf Gf-Patterns
```

### step 5 — update nuclei templates

nuclei needs its template library to actually scan for anything. Run this once to pull them down:

```bash
nuclei -update-templates
```

It downloads thousands of detection templates (CVEs, misconfigs, exposures, etc.) from the nuclei-templates repo.

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

If any of them are missing, it's probably a PATH issue. Go back to step 1 and make sure `$GOPATH/bin` is in your PATH.

---

## How to run

```bash
# clone the repo
git clone https://github.com/anishvedant/Lazy-recon.git
cd recon.sh

# make it executable
chmod +x recon.sh

# run it (needs sudo for nmap)
sudo ./recon.sh target.com
```
Replace `target.com` with whatever domain you have permission to test. The script creates a folder named after the domain in your current directory and dumps all the output there.

---

## Things to know

- needs **sudo** — nmap needs root for SYN scans, and gowitness needs `--no-sandbox` when running as root
- needs **internet** — the script pings 8.8.8.8 before starting to make sure youre connected
- runs scans **in parallel** so it's way faster than running everything one by one
- the live dashboard in the terminal shows progress for each module with a countdown timer.
- directory bruteforce only hits the **top 5 targets** to keep scan time reasonable. You can change that number in the script if you want more
- uses `/usr/share/wordlists/dirb/common.txt` by default. Edit the `WORDLIST` variable at the top of the script to use a different wordlist
- parallel tasks are capped at **15 minutes** timeout, so itdoesn'tt hang forever on huge scopes
- after the scan finishes, file permissions get fixed automatically so your normal (non-root) user can access and delete the output folder

---

## Disclaimer

This is for **authorized testing only**. Don't run this against targets you don't have written permission to test. I'm not responsible for how anyone uses this tool. Always get proper authorization before scanning anything.

---

## Todo/ideas

- [ ] add Slack/Discord webhook notifications when scan finishes
- [ ] generate an HTML report instead of plain text
- [ ] add flags to skip specific modules
- [ ] support for scanning IP ranges, not just domains
- [ ] option to use custom nuclei template folders

---

If you found this useful or want to suggest something, open an issue or send a PR.
