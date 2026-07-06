// Validates EN/ES translation parity: every English page under
// src/content/docs/ (outside es/) must have a Spanish counterpart at the same
// relative path under src/content/docs/es/, and vice-versa. Exits non-zero on
// any mismatch so CI catches a missing or orphaned translation.
import { readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const docsDir = fileURLToPath(new URL("../src/content/docs", import.meta.url));
const esDir = join(docsDir, "es");

function walk(dir) {
	const out = [];
	for (const entry of readdirSync(dir)) {
		const p = join(dir, entry);
		if (statSync(p).isDirectory()) {
			if (p === esDir) continue; // skip the ES subtree when collecting EN
			out.push(...walk(p));
		} else if (/\.(md|mdx)$/.test(entry)) {
			out.push(p);
		}
	}
	return out;
}

const enPages = walk(docsDir).map((p) => relative(docsDir, p));
const esPages = walk(esDir).map((p) => relative(esDir, p));

const enSet = new Set(enPages);
const esSet = new Set(esPages);

const missingEs = enPages.filter((p) => !esSet.has(p));
const orphanEs = esPages.filter((p) => !enSet.has(p));

if (missingEs.length || orphanEs.length) {
	for (const p of missingEs) console.error(`[i18n] missing Spanish translation: es/${p}`);
	for (const p of orphanEs) console.error(`[i18n] orphaned Spanish page (no EN source): es/${p}`);
	process.exit(1);
}
console.log(`[i18n] parity OK: ${enPages.length} pages in both locales`);
