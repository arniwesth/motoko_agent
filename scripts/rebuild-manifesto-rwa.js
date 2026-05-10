#!/usr/bin/env node
//
// Extracts a static reading copy from the rewritable manifesto.
// manifesto-rwa.html (source of truth) → manifesto.html (static export)
//
// Usage: node scripts/rebuild-manifesto-rwa.js
//

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'manifesto-rwa.html');
const DEST = path.join(ROOT, 'manifesto.html');

if (!fs.existsSync(SRC)) {
  console.error('manifesto-rwa.html not found at', SRC);
  process.exit(1);
}

const rwa = fs.readFileSync(SRC, 'utf8');

// Extract the HTML comment spec from the top
const specMatch = rwa.match(/(<!--[\s\S]*?-->)/);
const spec = specMatch ? specMatch[1] : '';

// Extract INLINE_DOC from the bootstrap script
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

// Unescape the template literal content
const raw = rwa.slice(cs, i)
  .replace(/\\`/g, '`')
  .replace(/\\\$/g, '$')
  .replace(/\\\\(?!\\)/g, '\\')
  .replace(/<\\\/script/gi, '<\/script');

// Split into style and body content
const styleMatch = raw.match(/<style>([\s\S]*?)<\/style>/);
const styleContent = styleMatch ? styleMatch[1] : '';
const bodyContent = raw.replace(/<style>[\s\S]*?<\/style>\s*/, '');

const staticHtml = `<!DOCTYPE html>
${spec}
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>The Motoko Manifesto</title>
  <style>${styleContent}</style>
</head>
<body>
${bodyContent}
</body>
</html>`;

fs.writeFileSync(DEST, staticHtml);
console.log('Exported static reading copy');
console.log('  Source: manifesto-rwa.html (%d bytes)', rwa.length);
console.log('  Output: manifesto.html (%d bytes)', staticHtml.length);
