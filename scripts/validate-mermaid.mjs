// Validate every ```mermaid block in the given Markdown files against the
// official mermaid parser. Exits non-zero on the first syntax error.
//   node scripts/validate-mermaid.mjs README.md PORTABILITY.md
//
// Deps (CI installs them): mermaid, jsdom@22
import fs from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!DOCTYPE html><body></body>', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.navigator = dom.window.navigator;
globalThis.HTMLElement = dom.window.HTMLElement;

const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });

const files = process.argv.slice(2);
let total = 0, failed = 0;

for (const file of files) {
  const text = fs.readFileSync(file, 'utf8');
  const re = /```mermaid\r?\n([\s\S]*?)```/g;
  let m, idx = 0;
  while ((m = re.exec(text)) !== null) {
    idx++; total++;
    const diagram = m[1];
    const firstLine = diagram.trim().split('\n')[0];
    try {
      await mermaid.parse(diagram);
      console.log(`PASS  ${file} #${idx}  (${firstLine})`);
    } catch (e) {
      failed++;
      console.log(`FAIL  ${file} #${idx}  (${firstLine})`);
      console.log(`      ${String(e.message || e).split('\n').join('\n      ')}`);
    }
  }
}

console.log(`\n${total} diagram(s), ${failed} failed`);
process.exit(failed ? 1 : 0);
