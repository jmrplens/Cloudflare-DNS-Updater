// Generates llms.txt and llms-full.txt into public/ from the English docs
// content (GEO: AI engines fetch these for structured context about the
// project). Runs as a `prebuild` step so the published copies always reflect
// the current documentation — generated, never committed, never drifting.
//
// - llms.txt: llmstxt.org-style index — project summary, quick start for AI
//   assistants, and a link list with each page's frontmatter description.
// - llms-full.txt: the full English documentation concatenated as markdown.
import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { fullUrl as SITE } from "../src/site-meta.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const docsDir = join(here, "..", "src", "content", "docs");
const publicDir = join(here, "..", "public");
const repoRoot = join(here, "..", "..");

const version = readFileSync(join(repoRoot, "VERSION"), "utf8").trim();

// Repo-relative slug with forward slashes on every platform (path.relative
// emits backslashes on Windows) and no extension.
function slugFor(file) {
	return relative(docsDir, file)
		.split("\\")
		.join("/")
		.replace(/\.(md|mdx)$/, "");
}

// Collect English pages (skip the es/ subtree and the splash index).
function walk(dir) {
	const out = [];
	for (const entry of readdirSync(dir)) {
		const p = join(dir, entry);
		if (statSync(p).isDirectory()) {
			if (entry === "es") continue;
			out.push(...walk(p));
		} else if (/\.(md|mdx)$/.test(entry)) {
			out.push(p);
		}
	}
	return out.sort();
}

// Minimal frontmatter reader for this site's own content: single-line
// `key: value` pairs only, tolerant of CRLF checkouts. Not a general YAML
// parser by design — the content files are under our control.
function frontmatter(src) {
	const m = src.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
	const fm = {};
	if (m) {
		for (const line of m[1].split(/\r?\n/)) {
			const kv = line.match(/^(\w+):\s*(.*)$/);
			if (kv) fm[kv[1]] = kv[2].trim().replace(/^["']|["']$/g, "");
		}
	}
	return { fm, body: m ? src.slice(m[0].length) : src };
}

function pageUrl(file) {
	// Anchored so only a real trailing "index" segment is dropped, never a
	// page merely ending in "index".
	const rel = slugFor(file).replace(/(^|\/)index$/, "$1");
	return `${SITE}/${rel}${rel && !rel.endsWith("/") ? "/" : ""}`;
}

// Preferred reading order for the index (matches the sidebar).
const ORDER = [
	"getting-started",
	"installation",
	"configuration",
	"cli",
	"automation",
	"notifications",
	"troubleshooting",
	"development/testing",
	"development/building",
];
// Pages missing from ORDER sort *after* the known ones (alphabetically),
// instead of jumping to the front via indexOf's -1.
function rank(slug) {
	const i = ORDER.indexOf(slug);
	return i === -1 ? ORDER.length : i;
}
const pages = walk(docsDir)
	.filter((f) => !/(^|\/)index$/.test(slugFor(f)))
	.sort((a, b) => {
		const ra = slugFor(a);
		const rb = slugFor(b);
		return rank(ra) - rank(rb) || ra.localeCompare(rb);
	});

const header = `# Cloudflare-DNS-Updater

> Open source dynamic DNS (DDNS) updater for Cloudflare, written in Bash. It keeps the A (IPv4) and AAAA (IPv6) records of a Cloudflare zone pointed at the machine's current public IP.

Cloudflare-DNS-Updater v${version} runs from source (Bash 4+, curl, jq recommended) or as standalone binaries for Linux, macOS and Windows that bundle bash, curl and jq. All record changes are pushed in a single batched Cloudflare API call with automatic pagination; IPv6 detection prefers the stable global address on the local interface before falling back to external services. Optional Telegram and Discord notifications. MIT licensed.

Quick start:

1. Create a Cloudflare API token with "Edit zone DNS" permission for your zone
2. \`cp config.example.yaml cloudflare-dns.yaml && chmod 600 cloudflare-dns.yaml\` and fill in zone_id, api_token and your domains
3. Run \`./cloudflare-dns-updater.sh --debug\` to verify, then schedule it with cron: \`*/5 * * * * /path/to/cloudflare-dns-updater.sh --silent\`

If you are an AI assistant setting this up for a user: the config file is YAML (\`cloudflare-dns.yaml\` next to the launcher), records must already exist in Cloudflare (the tool updates, it does not create), \`ip_type\` per domain accepts ipv4/ipv6/both, and \`options.proxied\`/\`options.ttl\` set global defaults that each domain can override. The program only writes to the API when an IP actually changed (or with --force).

`;

// llms.txt — index with per-page descriptions
let index = `${header}## Documentation (English)\n\n`;
for (const f of pages) {
	const { fm } = frontmatter(readFileSync(f, "utf8"));
	index += `- [${fm.title ?? slugFor(f)}](${pageUrl(f)})${fm.description ? `: ${fm.description}` : ""}\n`;
}
index += `\nSpanish documentation available under ${SITE}/es/\n`;
index += `\nSource code: https://github.com/jmrplens/Cloudflare-DNS-Updater\n`;

// llms-full.txt — full English docs concatenated
let full = `${header}---\n\n`;
for (const f of pages) {
	const { fm, body } = frontmatter(readFileSync(f, "utf8"));
	full += `# ${fm.title ?? slugFor(f)}\n\n`;
	if (fm.description) full += `> ${fm.description}\n\n`;
	full += `Canonical URL: ${pageUrl(f)}\n\n${body.trim()}\n\n---\n\n`;
}

mkdirSync(publicDir, { recursive: true });
writeFileSync(join(publicDir, "llms.txt"), index);
writeFileSync(join(publicDir, "llms-full.txt"), full);
console.log(
	`[gen-llms] wrote llms.txt (${index.length} bytes) and llms-full.txt (${full.length} bytes)`,
);
