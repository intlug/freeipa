#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = new Set(process.argv.slice(2));
const writeMode = args.has('--write');
const checkMode = args.has('--check') || !writeMode;

const targetFile = path.resolve(process.cwd(), 'slides.md');
const source = fs.readFileSync(targetFile, 'utf8');

const classDirectivePattern = /<!--\s*_class:\s*([^>]*?)\s*-->/g;
let changedCount = 0;

const updated = source.replace(classDirectivePattern, (fullMatch, classBody) => {
  const classes = classBody.trim().split(/\s+/).filter(Boolean);
  if (classes.includes('invert')) {
    return fullMatch;
  }
  changedCount += 1;
  const merged = [...classes, 'invert'].join(' ');
  return `<!-- _class: ${merged} -->`;
});

if (changedCount === 0) {
  console.log('All _class directives already include invert.');
  process.exit(0);
}

if (writeMode) {
  fs.writeFileSync(targetFile, updated, 'utf8');
  console.log(`Updated ${changedCount} _class directive(s) to include invert.`);
  process.exit(0);
}

if (checkMode) {
  console.error(`Found ${changedCount} _class directive(s) missing invert.`);
  console.error('Run: npm run fix:invert-class');
  process.exit(1);
}
