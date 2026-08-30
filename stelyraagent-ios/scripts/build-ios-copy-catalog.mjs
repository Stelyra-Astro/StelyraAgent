#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const SUPPORTED_LOCALES = new Set(['en', 'zh-Hans', 'es', 'fr', 'de', 'it', 'pt-BR', 'tr', 'ko']);
const VARIABLE_TYPES = {
  planet: 'body',
  first: 'body',
  second: 'body',
  transitPlanet: 'body',
  sign: 'sign',
  houseLabel: 'house',
  lifeAreas: 'houseList',
  aspect: 'aspect',
  phase: 'phase',
  intensity: 'intensity',
  orb: 'intensity',
  percent: 'percentage',
  count: 'count',
  date: 'date',
  start: 'date',
  end: 'date',
  day: 'date',
  time: 'time',
  duration: 'duration',
  otherName: 'personName',
};

function fail(message) {
  console.error(message);
  process.exit(1);
}

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJSON(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function variableNames(value) {
  const matches = [...value.matchAll(/\{\{([A-Za-z][A-Za-z0-9]*)\}\}/g)].map((match) => match[1]);
  return [...new Set(matches)];
}

function slug(sourcePath) {
  return sourcePath
    .toLowerCase()
    .replace(/[^a-z0-9.-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/(^[-.]+|[-.]+$)/g, '');
}

function flattenStrings(value, prefix, output) {
  if (typeof value === 'string') {
    if (value.length === 0) return;
    const variables = variableNames(value).map((name) => {
      const type = VARIABLE_TYPES[name];
      if (!type) throw new Error(`Unknown copy variable {{${name}}} at ${prefix}`);
      return { name, type };
    });
    output.push({
      sourcePath: prefix,
      value,
      variables,
      kind: prefix.startsWith('shared.technical.') ? 'technical' : 'consumer',
    });
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => flattenStrings(item, `${prefix}.${index}`, output));
    return;
  }
  if (value && typeof value === 'object') {
    Object.entries(value).forEach(([key, child]) => {
      flattenStrings(child, prefix ? `${prefix}.${key}` : key, output);
    });
  }
}

function normalizedSources(value) {
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return [];
  return value.split('+').map((part) => part.trim()).filter(Boolean);
}

function buildContracts(source) {
  const contracts = [];
  for (const [technique, cards] of Object.entries(source.contracts ?? {})) {
    for (const [cardID, item] of Object.entries(cards)) {
      contracts.push({
        id: `${technique}.${cardID}`,
        technique,
        cardID,
        selector: `${technique}.${cardID}.v1`,
        facts: item.facts ?? [],
        evidenceByPreset: item.evidenceByPreset ?? {},
        textFields: item.textFields ?? [],
        copySourceByPreset: Object.fromEntries(
          Object.entries(item.copySourceByPreset ?? {}).map(([preset, sources]) => [preset, normalizedSources(sources)])
        ),
      });
    }
  }
  return contracts;
}

function buildThemeRules(source) {
  let sequence = 1;
  const result = {};
  for (const preset of ['modern', 'classical']) {
    const rules = source[preset]?.transit?.themeRules ?? [];
    result[preset] = rules.map((rule) => ({
      id: `theme-rule.${String(sequence++).padStart(3, '0')}`,
      pair: rule.pair,
      tone: rule.tone,
      themeID: rule.themeID,
    }));
  }
  return result;
}

function buildRuntime(source) {
  if (!source || typeof source !== 'object') throw new Error('Source catalog must be a JSON object.');
  if (!SUPPORTED_LOCALES.has(source.locale)) throw new Error(`Unsupported locale: ${source.locale}`);
  if (source.status !== 'approved') throw new Error(`Source catalog must be approved, got: ${source.status}`);
  if (!source.version) throw new Error('Source catalog is missing version.');

  const flattened = [];
  for (const root of ['shared', 'modern', 'classical']) {
    flattenStrings(source[root] ?? {}, root, flattened);
  }
  const seen = new Set();
  const entries = flattened.map((entry) => {
    if (seen.has(entry.sourcePath)) throw new Error(`Duplicate source path: ${entry.sourcePath}`);
    seen.add(entry.sourcePath);
    return {
      id: `copy.${slug(entry.sourcePath)}`,
      locale: source.locale,
      status: 'approved',
      kind: entry.kind,
      sourcePath: entry.sourcePath,
      value: entry.value,
      variables: entry.variables,
    };
  });

  return {
    schemaVersion: 2,
    contentVersion: source.version,
    locale: source.locale,
    status: source.status,
    contracts: buildContracts(source),
    entries,
    themeRulesByPreset: buildThemeRules(source),
  };
}

function validateRuntime(runtime) {
  const errors = [];
  if (runtime.schemaVersion !== 2) errors.push('schemaVersion must be 2');
  if (!runtime.contentVersion) errors.push('contentVersion is required');
  if (!SUPPORTED_LOCALES.has(runtime.locale)) errors.push(`unsupported locale ${runtime.locale}`);
  if (runtime.status !== 'approved') errors.push('status must be approved');
  if (!Array.isArray(runtime.contracts) || runtime.contracts.length !== 51) errors.push('contracts must contain exactly 51 entries');
  if (!Array.isArray(runtime.entries) || runtime.entries.length === 0) errors.push('entries must be non-empty');
  if (!runtime.themeRulesByPreset || !Array.isArray(runtime.themeRulesByPreset.modern) || !Array.isArray(runtime.themeRulesByPreset.classical)) {
    errors.push('themeRulesByPreset must contain modern and classical arrays');
  }

  const paths = new Set();
  const ids = new Set();
  for (const entry of runtime.entries ?? []) {
    if (entry.locale !== runtime.locale) errors.push(`entry locale mismatch at ${entry.sourcePath}`);
    if (entry.status !== 'approved') errors.push(`non-approved entry at ${entry.sourcePath}`);
    if (!entry.sourcePath || paths.has(entry.sourcePath)) errors.push(`duplicate or empty sourcePath ${entry.sourcePath}`);
    paths.add(entry.sourcePath);
    if (!entry.id || ids.has(entry.id)) errors.push(`duplicate or empty entry id ${entry.id}`);
    ids.add(entry.id);
    const placeholders = new Set(variableNames(entry.value ?? ''));
    const declared = new Set((entry.variables ?? []).map((item) => item.name));
    if (placeholders.size !== declared.size || [...placeholders].some((name) => !declared.has(name))) {
      errors.push(`placeholder declaration mismatch at ${entry.sourcePath}`);
    }
  }

  const contractIDs = new Set();
  for (const contract of runtime.contracts ?? []) {
    if (contractIDs.has(contract.id)) errors.push(`duplicate contract id ${contract.id}`);
    contractIDs.add(contract.id);
  }

  if (errors.length) throw new Error(errors.join('\n'));
  return runtime;
}

const [command, ...args] = process.argv.slice(2);
try {
  if (command === '--build') {
    if (args.length !== 2) fail('Usage: build-ios-copy-catalog.mjs --build <source.json> <runtime.json>');
    const [sourcePath, outputPath] = args;
    const runtime = validateRuntime(buildRuntime(readJSON(sourcePath)));
    writeJSON(outputPath, runtime);
    console.log(JSON.stringify({ locale: runtime.locale, entries: runtime.entries.length, contracts: runtime.contracts.length }));
  } else if (command === '--validate-runtime') {
    if (args.length !== 1) fail('Usage: build-ios-copy-catalog.mjs --validate-runtime <runtime.json>');
    const runtime = validateRuntime(readJSON(args[0]));
    console.log(JSON.stringify({ valid: true, locale: runtime.locale, entries: runtime.entries.length }));
  } else {
    fail('Usage: build-ios-copy-catalog.mjs --build <source.json> <runtime.json> | --validate-runtime <runtime.json>');
  }
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
