# \# ReconCore

# 

# \*\*Advanced Reconnaissance \& DNS Enumeration Framework\*\*

# 

# ReconCore is a Bash-based reconnaissance automation framework built to streamline the early stages of external penetration testing and attack surface mapping. Instead of running a dozen separate tools by hand and manually collating their output, ReconCore wires them together into a single, repeatable pipeline that produces a clean, per-target results directory every time it runs.

# 

# Given nothing but a domain name, the framework will:

# 

# \- Pull WHOIS and DNS metadata

# \- Enumerate subdomains from multiple independent sources

# \- Determine which discovered hosts are actually alive

# \- Fingerprint the technology stack and WAF/CDN in front of the target

# \- Collect historical/archived URLs across every discovered subdomain, not just the root domain

# \- Optionally crawl the site and brute-force hidden paths

# 

# Everything is written to disk in a structured, analyst-friendly format so results can be reviewed, diffed against previous scans, or fed into a reporting pipeline. The framework can also run entirely through an interactive menu, with no flags required.

# 

# \---

# 

# \## Table of Contents

# 

# \- \[Why This Project Exists](#why-this-project-exists)

# \- \[Design Philosophy](#design-philosophy)

# \- \[Prerequisites \& Installation](#prerequisites--installation)

# \- \[Command-Line Interface](#command-line-interface)

# \- \[Usage Examples](#usage-examples)

# \- \[Interactive Mode](#interactive-mode)

# \- \[Output Organization](#output-organization)

# \- \[Phase-by-Phase Breakdown](#phase-by-phase-breakdown)

# \- \[Full Scan Mode](#full-scan-mode)

# \- \[Workflow Diagram](#workflow-diagram)

# \- \[Known Limitations](#known-limitations)

# \- \[Ethical \& Legal Notice](#ethical--legal-notice)

# 

# \---

# 

# \## Why This Project Exists

# 

# Reconnaissance is the first and most repetitive phase of almost any external assessment. The same sequence of steps — DNS lookups, subdomain discovery, HTTP probing, WAF detection, fingerprinting, URL collection — gets performed against every single target. Doing this manually means:

# 

# \- Re-typing (or re-remembering) the same commands for every engagement

# \- Losing track of which output belongs to which tool or target

# \- Forgetting a step under time pressure

# \- Wasting time on setup instead of analysis

# 

# Automating the pipeline removes that overhead entirely and lets the analyst focus on interpreting results instead of producing them.

# 

# \## Design Philosophy

# 

# \- \*\*One target, one folder\*\* — every run creates a dedicated output directory, so nothing from different engagements ever mixes.

# \- \*\*One tool, one file\*\* — each tool's raw output is preserved in its own file.

# \- \*\*Warn, don't gate, on missing dependencies\*\* — a missing tool is reported before the scan starts, but the scan proceeds regardless.

# \- \*\*Passive first, active on demand\*\* — the default run performs DNS/WHOIS/subdomain/HTTP-probe/historical-URL gathering. More intrusive checks (reverse DNS, WAF probing, fingerprinting, security headers, SSL analysis) are skipped when `-p` is set.

# \- \*\*Broad coverage on historical data\*\* — archived-URL collection runs against the full deduplicated subdomain list, not just the apex domain.

# \- \*\*Clean, parseable output\*\* — colored/ANSI output is disabled wherever possible, since raw text files are meant to be read, grepped, and parsed.

# \- \*\*No excuse not to run it\*\* — flag-driven automation and a guided interactive mode mean there's no barrier to firing off a scan.

# 

# \## Prerequisites \& Installation

# 

# Built for \*\*Kali Linux\*\* (or any Debian-based distro). Assumes Go is available for the ProjectDiscovery tool suite.

# 

# | Category | Tools |

# |---|---|

# | DNS / WHOIS | `dig`, `whois` |

# | HTTP | `curl` |

# | Subdomain discovery | `subfinder`, `assetfinder`, `findomain` |

# | Live host resolution | `dnsx` |

# | HTTP probing | `httpx` |

# | Fingerprinting | `whatweb`, `wafw00f` |

# | SSL/TLS | `sslscan` |

# | Directory brute-forcing | `ffuf` |

# | Historical URLs | `gau` |

# | Crawling | `katana` |

# 

# \### Installation

# 

# ```bash

# sudo apt update

# sudo apt install -y dnsutils whois curl golang-go whatweb sslscan git

# export PATH=$PATH:$(go env GOPATH)/bin

# 

# go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest

# go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

# go install -v github.com/projectdiscovery/katana/cmd/katana@latest

# go install -v github.com/tomnomnom/assetfinder@latest

# go install -v github.com/lc/gau/v2/cmd/gau@latest

# go install -v github.com/ffuf/ffuf/v2@latest

# pip install wafw00f --break-system-packages

# 

# curl -LO https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip

# unzip findomain-linux.zip \&\& chmod +x findomain \&\& sudo mv findomain /usr/local/bin/

# ```

# 

# A SecLists-based wordlist is also expected at:

# 

# ```

# /usr/share/seclists/Discovery/Web-Content/common.txt

# ```

# 

# \## Command-Line Interface

# 

# | Flag | Meaning | Required |

# |---|---|---|

# | `-d` | Target domain | No — omit to enter interactive mode |

# | `-o` | Output directory (default: `recon-<domain>`) | No |

# | `-t` | Thread count (default: 50) | No |

# | `-w` | Custom wordlist path | No |

# | `-s` | Silent mode — suppresses progress messages and the loading animation | No |

# | `-p` | Passive-only — skips reverse lookup, WAF, fingerprinting, headers, SSL | No |

# | `-f` | Full scan mode — adds crawling and directory brute-forcing | No |

# | `-h` | Show help and exit | No |

# 

# If `-d` is omitted, the script doesn't exit — it drops straight into full interactive setup instead, so it can be run with zero arguments.

# 

# \## Usage Examples

# 

# Fully interactive run (no flags at all):

# ```bash

# ./ReconCore.sh

# ```

# 

# Direct mode, passive-leaning run:

# ```bash

# ./ReconCore.sh -d target.com

# ```

# 

# Explicit passive-only run (skips reverse DNS, WAF, fingerprinting, headers, SSL):

# ```bash

# ./ReconCore.sh -d target.com -p

# ```

# 

# Full scan, including crawling and directory brute-forcing:

# ```bash

# ./ReconCore.sh -d target.com -f

# ```

# 

# Custom output folder, higher thread count, custom wordlist:

# ```bash

# ./ReconCore.sh -d target.com -f -o results-target -t 100 -w /path/to/wordlist.txt

# ```

# 

# Silent run (suppresses framework progress messages and the loading animation):

# ```bash

# ./ReconCore.sh -d target.com -s

# ```

# 

# \## Interactive Mode

# 

# If no `-d` is supplied on the command line, the script walks the operator through setup instead of exiting. `interactive\_setup()` prompts, in order, for:

# 

# \- Target domain (required — re-prompts until non-empty)

# \- Output directory (defaults to `recon-<domain>`)

# \- Thread count (defaults to 50)

# \- Custom wordlist path (defaults to the built-in SecLists path)

# \- Silent mode (y/N)

# 

# `start\_menu()` then presents a scan-mode menu once:

# 

# ```

# 1\) Quick Scan     (Passive recon only)

# 2\) Full Scan      (Passive + Crawling + Fuzzing)

# 3\) Continue with current settings

# 4\) Help Menu

# 5\) Exit

# ```

# 

# \## Output Organization

# 

# After argument parsing (and interactive setup, if applicable), the framework creates the results folder and writes every phase's raw output into it using a predictable filename:

# 

# ```

# recon-target.com/

# ├── whois.txt

# ├── A.txt / AAAA.txt / MX.txt / NS.txt / TXT.txt / SOA.txt / CNAME.txt / CAA.txt / SRV.txt / ANY.txt

# ├── resolver-1.1.1.1.txt / resolver-8.8.8.8.txt / resolver-9.9.9.9.txt

# ├── dns-trace.txt

# ├── reverse-dns.txt        (active mode only)

# ├── subfinder.txt / assetfinder.txt / findomain.txt / all-subdomains.txt

# ├── live-hosts.txt

# ├── httpx.txt

# ├── waf.txt                (active mode only)

# ├── whatweb.txt            (active mode only)

# ├── security-headers.txt   (active mode only)

# ├── sslscan.txt            (active mode only)

# ├── gau.txt

# ├── katana.txt             (full scan only)

# ├── ffuf.txt               (full scan only)

# └── summary.txt

# ```

# 

# \## Phase-by-Phase Breakdown

# 

# 1\. \*\*WHOIS Enumeration\*\* — pulls domain registration data (registrar, creation/expiry dates, registrant contact when not redacted).

# 2\. \*\*DNS Record Enumeration\*\* — queries ten common record types individually (A, AAAA, MX, NS, TXT, SOA, CNAME, CAA, SRV, ANY).

# 3\. \*\*Resolver Testing\*\* — repeats the lookup against three independent public resolvers (Cloudflare, Google, Quad9) to reveal geo-routing or split-horizon DNS.

# 4\. \*\*DNS Trace\*\* — walks the full resolution path from the root servers to the authoritative name server.

# 5\. \*\*Subdomain Enumeration\*\* — runs `subfinder`, `assetfinder`, and `findomain` in sequence and deduplicates the combined output.

# 6\. \*\*Live Host Resolution\*\* — filters the subdomain list down to hosts that actually resolve, using `dnsx`.

# 7\. \*\*HTTP Probing\*\* — the centerpiece of the framework; captures status code, page title, server header, CDN, and full tech stack for every live subdomain via `httpx`.

# 8\. \*\*Historical URL Collection\*\* — pulls archived URLs via `gau` across the entire deduplicated subdomain list, not just the apex domain.

# 9\. \*\*Reverse DNS Lookup\*\* \*(active mode only)\* — resolves every discovered IP back to a hostname to spot shared hosting or unexpected infrastructure.

# 10\. \*\*WAF Detection\*\* \*(active mode only)\* — fingerprints any WAF sitting in front of the target with `wafw00f`.

# 11\. \*\*Technology Fingerprinting\*\* \*(active mode only)\* — a second, independent fingerprinting pass with `whatweb`.

# 12\. \*\*Security Headers\*\* \*(active mode only)\* — captures raw response headers for security review (HSTS, CSP, X-Frame-Options, etc.).

# 13\. \*\*SSL/TLS Analysis\*\* \*(active mode only)\* — enumerates supported TLS versions and cipher suites with `sslscan`, flagging weak configurations.

# 

# Phases 1–8 run unconditionally on every scan. Phases 9–13 are skipped entirely when `-p` (Passive Only) is set.

# 

# \## Full Scan Mode

# 

# Only executes when `-f` is passed, since these phases generate meaningful, sustained load against the live target:

# 

# \- \*\*Crawling\*\* — actively crawls the site (including JavaScript parsing for embedded endpoints) via `katana`.

# \- \*\*Directory Enumeration\*\* — brute-forces the target with a wordlist via `ffuf` to surface hidden directories and admin panels.

# \- \*\*Summary Generation\*\* — writes a summary file combining the run's key findings.

# 

# \## Workflow Diagram

# 

# ```

# Target Domain

# &#x20;    ↓

# Create Output Directory

# &#x20;    ↓

# Dependency Check

# &#x20;    ↓

# WHOIS Enumeration

# &#x20;    ↓

# DNS Enumeration (records + resolvers + trace)

# &#x20;    ↓

# Subdomain Discovery

# &#x20;    ↓

# Live Host Resolution

# &#x20;    ↓

# HTTP Probing

# &#x20;    ↓

# Historical URL Collection

# &#x20;    ↓

# (if not -p) WAF Detection, Fingerprinting, Reverse DNS, Security Headers, SSL Analysis

# &#x20;    ↓

# (if -f) Crawling + Directory Enumeration

# &#x20;    ↓

# Summary Generation

# ```

# 

# \## Known Limitations

# 

# \- No command timeouts anywhere — a slow or unresponsive name server or a hung crawl can block the pipeline indefinitely.

# \- No dependency confirmation gate — a scan can run to completion with most of its tools missing.

# \- No thread-count or wordlist-existence validation before use.

# \- Largely unquoted variable expansions throughout.

# \- `start\_menu()` runs once rather than in a loop — an invalid selection exits the script instead of re-prompting.

# \- `summary.txt` is minimal (header line + raw `httpx` output only).

# \- No parallelism — all phases run strictly sequentially.

# 

# \## Ethical \& Legal Notice

# 

# Several phases in this framework — most notably reverse DNS lookups, WAF probing, and directory brute-forcing — are \*\*active techniques\*\* that send a meaningful volume of requests directly to the target's infrastructure. Running these against any domain without explicit written authorization (a signed engagement scope, a bug bounty program's published rules, or infrastructure you personally own) can be illegal in most jurisdictions.

# 

# This framework is intended strictly for:

# 

# \- Authorized penetration testing engagements

# \- Bug bounty programs with the target in scope

# \- Personal lab environments

# 

# The `-p` flag exists specifically so a scan can be scoped down to passive-only techniques when active testing hasn't been authorized.

# 

# \---

# 

# \*\*Author:\*\* Ali Mohamed Shafek — \[GitHub](https://github.com/Ali8507R)

