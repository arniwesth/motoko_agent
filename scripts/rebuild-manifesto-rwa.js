#!/usr/bin/env node
//
// Rebuilds manifesto-rwa.html from manifesto.html.
// Extracts styles + body content, wraps in the rewritable bootstrap,
// preserves frozen zones and the rwa-edit/1 runtime.
//
// Usage: node scripts/rebuild-manifesto-rwa.js
//

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'manifesto.html');
const DEST = path.join(ROOT, 'manifesto-rwa.html');

if (!fs.existsSync(SRC)) {
  console.error('manifesto.html not found at', SRC);
  process.exit(1);
}

if (!fs.existsSync(DEST)) {
  console.error('manifesto-rwa.html not found at', DEST);
  console.error('Run the initial build first — this script only updates an existing container.');
  process.exit(1);
}

const html = fs.readFileSync(SRC, 'utf8');
const rwa = fs.readFileSync(DEST, 'utf8');

const styleMatch = html.match(/<style>([\s\S]*?)<\/style>/);
const bodyMatch = html.match(/<body>([\s\S]*?)<\/body>/);

if (!styleMatch || !bodyMatch) {
  console.error('Could not extract <style> or <body> from manifesto.html');
  process.exit(1);
}

const inlineDoc = '<style>' + styleMatch[1] + '<\/style>\n' + bodyMatch[1].trim();

function escapeTL(s) {
  return s
    .replace(/\\/g, '\\\\')
    .replace(/`/g, '\\`')
    .replace(/\$\{/g, '\\${')
    .replace(/<\/script/gi, '<\\/script');
}

const marker = 'const INLINE_DOC = `';
const start = rwa.indexOf(marker);
if (start < 0) {
  console.error('Could not locate INLINE_DOC in manifesto-rwa.html');
  process.exit(1);
}

const cs = start + marker.length;
let i = cs;
while (i < rwa.length) {
  if (rwa[i] === '\\') { i += 2; continue; }
  if (rwa[i] === '`') break;
  i++;
}

if (i >= rwa.length) {
  console.error('Unterminated INLINE_DOC template literal');
  process.exit(1);
}

const updated = rwa.slice(0, cs) + escapeTL(inlineDoc) + rwa.slice(i);

// Also update the HTML comment spec at the top if it changed
const srcSpec = html.match(/(<!--[\s\S]*?-->)/);
const destSpec = updated.match(/(<!--[\s\S]*?-->)/);
let final = updated;
if (srcSpec && destSpec && srcSpec[1] !== destSpec[1]) {
  final = updated.replace(destSpec[1], srcSpec[1]);
}

fs.writeFileSync(DEST, final);

const frozenCount = (inlineDoc.match(/rwa:frozen:begin/g) || []).length;
console.log('Rebuilt manifesto-rwa.html');
console.log('  INLINE_DOC: %d bytes', inlineDoc.length);
console.log('  Frozen zones: %d', frozenCount);
console.log('  Total: %d bytes', final.length);
