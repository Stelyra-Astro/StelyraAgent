#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceRoot = path.join(root, 'ios', 'PrivateContent');
const defaultOutput = path.join(root, 'ios', 'App', 'Resources', 'PrivateContent');
const copyCatalogBuilder = path.join(root, 'scripts', 'build-ios-copy-catalog.mjs');
const localeOrder = ['en', 'zh-Hans', 'es', 'fr', 'de', 'it', 'pt-BR', 'tr', 'ko'];

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  let command = null;
  let output = defaultOutput;
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--build' || value === '--validate') command = value;
    else if (value === '--output') output = path.resolve(argv[++index]);
    else fail(`Unknown argument: ${value}`);
  }
  return { command, output };
}

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function placeholderSet(value) {
  return [...new Set([...String(value).matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)].map((match) => match[1]))].sort();
}

function validateContentPack(file, area, locale, referenceKeys = null) {
  const pack = readJSON(file);
  if (pack.schemaVersion !== 1) throw new Error(`${file}: schemaVersion must be 1`);
  if (pack.area !== area) throw new Error(`${file}: area must be ${area}`);
  if (pack.locale !== locale) throw new Error(`${file}: locale must be ${locale}`);
  if (!Array.isArray(pack.entries) || pack.entries.length === 0) throw new Error(`${file}: entries must be non-empty`);
  const keys = new Set();
  for (const entry of pack.entries) {
    if (!entry.contentKey || keys.has(entry.contentKey)) throw new Error(`${file}: duplicate/empty contentKey ${entry.contentKey}`);
    keys.add(entry.contentKey);
    if (entry.translationStatus !== 'approved') throw new Error(`${file}: ${entry.contentKey} is not approved`);
  }
  if (referenceKeys) {
    if (keys.size !== referenceKeys.size || [...referenceKeys].some((key) => !keys.has(key))) {
      throw new Error(`${file}: contentKey coverage differs from English authoritative pack`);
    }
  }
  return pack;
}

function validatePlaceholderParity(reference, target, file) {
  const targetMap = new Map(target.entries.map((entry) => [entry.contentKey, entry]));
  for (const sourceEntry of reference.entries) {
    const translated = targetMap.get(sourceEntry.contentKey);
    for (const field of ['summary', 'detail']) {
      const expected = placeholderSet(sourceEntry[field] ?? '');
      const actual = placeholderSet(translated?.[field] ?? '');
      if (JSON.stringify(expected) !== JSON.stringify(actual)) {
        throw new Error(`${file}: placeholder mismatch ${sourceEntry.contentKey}.${field}: ${expected} != ${actual}`);
      }
    }
  }
}

function copyContentArea(area, output, write) {
  const dir = path.join(sourceRoot, area);
  if (!fs.existsSync(dir)) return [];
  const englishFile = path.join(dir, 'Content-en.json');
  if (!fs.existsSync(englishFile)) throw new Error(`${area}: missing Content-en.json`);
  const english = validateContentPack(englishFile, area, 'en');
  const englishKeys = new Set(english.entries.map((entry) => entry.contentKey));
  const generated = [];
  for (const locale of localeOrder) {
    const source = path.join(dir, `Content-${locale}.json`);
    if (!fs.existsSync(source)) continue;
    const pack = validateContentPack(source, area, locale, englishKeys);
    validatePlaceholderParity(english, pack, source);
    const destination = path.join(output, `PrivateContent-${area}-${locale}.json`);
    if (write) fs.copyFileSync(source, destination);
    generated.push(destination);
  }
  return generated;
}

function buildChartCatalogs(output, write) {
  const dir = path.join(sourceRoot, 'charts');
  if (!fs.existsSync(dir)) return [];
  const generated = [];
  for (const locale of localeOrder) {
    const source = path.join(dir, `StelyraAgent_Copy_Catalog_${locale}_v2_three-layers.json`);
    if (!fs.existsSync(source)) continue;
    const destination = path.join(output, `CopyCatalog-${locale}.json`);
    if (write) {
      execFileSync(process.execPath, [copyCatalogBuilder, '--build', source, destination], { stdio: 'pipe' });
    } else {
      const temporary = path.join(output, `.validate-CopyCatalog-${locale}.json`);
      execFileSync(process.execPath, [copyCatalogBuilder, '--build', source, temporary], { stdio: 'pipe' });
      fs.rmSync(temporary, { force: true });
    }
    generated.push(destination);
  }
  return generated;
}

const { command, output } = parseArgs(process.argv.slice(2));
if (!command) fail('Usage: build-ios-private-content.mjs --build|--validate [--output <dir>]');
try {
  fs.mkdirSync(output, { recursive: true });
  if (command === '--build') {
    for (const file of fs.readdirSync(output)) {
      if (/^(PrivateContent-(today|ask)-|CopyCatalog-).*\.json$/.test(file)) fs.rmSync(path.join(output, file));
    }
  }
  const write = command === '--build';
  const generated = [
    ...copyContentArea('today', output, write),
    ...copyContentArea('ask', output, write),
    ...buildChartCatalogs(output, write),
  ];
  console.log(JSON.stringify({ valid: true, generated: generated.length, output }));
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
