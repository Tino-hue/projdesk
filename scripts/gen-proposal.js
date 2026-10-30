#!/usr/bin/env node
// Generate PROPOSAL.md from SUBMISSION-TEXT.md.
//
// The two documents say the same thing: one is the plain text that goes into
// the registration form, the other is the same content as markdown. Keeping
// them apart by hand is how they drift, so one is generated from the other.
//
// Usage: node scripts/gen-proposal.js
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'SUBMISSION-TEXT.md');
const OUT = join(ROOT, 'PROPOSAL.md');

const src = readFileSync(SRC, 'utf8');
const lines = src.split('\n');

const out = ['# ProjDesk 项目申报书', ''];
let i = lines[0].startsWith('ProjDesk：') ? 1 : 0;
let code = [];
const flushCode = () => {
  if (code.length === 0) return;
  out.push('```', ...code, '```', '');
  code = [];
};

while (i < lines.length) {
  const line = lines[i];
  if (line.startsWith('    ')) {
    code.push(line.slice(4));
    i += 1;
    continue;
  }
  // anything that is not indented ends the code block; a blank line is kept
  flushCode();
  if (line.trim() === '') {
    out.push('');
    i += 1;
    continue;
  }
  const m = /^([一二三四五六七八九十]+)、\s*(.+)$/.exec(line);
  if (m) {
    out.push(`## ${m[2]}`, '');
  } else {
    out.push(line);
  }
  i += 1;
}
flushCode();

const text = out.join('\n').replace(/\n{3,}/g, '\n\n').replace(/\s+$/, '') + '\n';
writeFileSync(OUT, text, 'utf8');
console.log(`PROPOSAL.md regenerated from SUBMISSION-TEXT.md (${(text.match(/^## /gm) || []).length} sections)`);
