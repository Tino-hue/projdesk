#!/usr/bin/env node
// Generate PROPOSAL.md from SUBMISSION-TEXT.md.
//
// Both files say the same thing — one is what goes into the registration
// form, the other is the repository's copy of it. Keeping them apart by hand
// is how their numbers came to disagree, so one is generated from the other.
//
// Usage: node scripts/gen-proposal.js
import { readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = join(ROOT, 'SUBMISSION-TEXT.md');
const OUT = join(ROOT, 'PROPOSAL.md');

const text = readFileSync(SRC, 'utf8');
const out = text.replace(/^# .*$/m, '# ProjDesk 项目申报书');
writeFileSync(OUT, out, 'utf8');
console.log('PROPOSAL.md regenerated from SUBMISSION-TEXT.md');
