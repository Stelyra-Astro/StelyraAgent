#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const appDir = path.join(root, "ios", "App");
const translationDirectory = path.join(root, "ios", "Localization", "UI");
const outputPath = path.join(appDir, "Localizable.xcstrings");
const validateOnly = process.argv.includes("--validate");
const termKeys = {
  bodies: ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune", "pluto", "trueNode", "lilith", "partOfFortune", "juno"],
  zodiac: ["aries", "taurus", "gemini", "cancer", "leo", "virgo", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"],
  aspects: ["conjunction", "sextile", "square", "trine", "opposition"],
  aspectPhases: ["applying", "exact", "separating"],
  motions: ["direct", "retrograde", "stationary"],
  elements: ["fire", "earth", "air", "water"],
  modalities: ["cardinal", "fixed", "mutable"],
  angles: ["ascendant", "descendant", "midheaven", "imumCoeli"],
  moonPhases: ["new-moon", "waxing-crescent", "first-quarter", "waxing-gibbous", "full-moon", "waning-gibbous", "last-quarter", "waning-crescent"],
  chartKinds: ["natal", "currentSky", "transit", "secondary", "solarReturn", "synastry"],
  formats: ["house"],
};

for (const locale of ["en", "zh-Hans", "es", "fr", "tr", "de", "it", "pt-BR", "ko"]) {
  const termPath = path.join(appDir, "Resources", `AstroTerms-${locale}.json`);
  const catalog = JSON.parse(fs.readFileSync(termPath, "utf8"));
  if (catalog.version !== 1 || catalog.locale !== locale) throw new Error(`Invalid AstroTerms header: ${locale}`);
  const actualCategories = Object.keys(catalog).filter((key) => !["version", "locale"].includes(key)).sort();
  const expectedCategories = Object.keys(termKeys).sort();
  if (JSON.stringify(actualCategories) !== JSON.stringify(expectedCategories)) {
    throw new Error(`AstroTerms category mismatch: ${locale}`);
  }
  for (const [category, expectedKeys] of Object.entries(termKeys)) {
    const values = catalog[category];
    const actualKeys = values && typeof values === "object" ? Object.keys(values).sort() : [];
    if (JSON.stringify(actualKeys) !== JSON.stringify([...expectedKeys].sort())) {
      throw new Error(`AstroTerms ${category} keys mismatch: ${locale}`);
    }
    if (Object.values(values).some((value) => typeof value !== "string" || !value.trim())) {
      throw new Error(`AstroTerms ${category} contains an empty/non-string value: ${locale}`);
    }
  }
}

function swiftFilesUnder(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return swiftFilesUnder(entryPath);
    return entry.isFile() && entry.name.endsWith(".swift") ? [entryPath] : [];
  });
}

const swiftFiles = swiftFilesUnder(appDir);
const translationFiles = fs.readdirSync(translationDirectory)
  .filter((name) => name.endsWith(".json"))
  .sort();
if (!translationFiles.length) throw new Error("No UI localization fragments found");
const translations = {};
for (const fileName of translationFiles) {
  const fragmentPath = path.join(translationDirectory, fileName);
  const fragment = JSON.parse(fs.readFileSync(fragmentPath, "utf8"));
  for (const [key, value] of Object.entries(fragment)) {
    if (Object.hasOwn(translations, key)) {
      throw new Error(`Duplicate UI localization key ${key} in ${fileName}`);
    }
    translations[key] = value;
  }
}
const locales = ["en", "zh", "es", "fr", "tr", "de", "it", "pt-BR", "ko"];
const catalogLocale = { en: "en", zh: "zh-Hans", es: "es", fr: "fr", tr: "tr", de: "de", it: "it", "pt-BR": "pt-BR", ko: "ko" };
const referencedKeys = new Set();
const legacyCalls = [];
const missingKeys = [];

function placeholders(value) {
  return (value.match(/\{\{[A-Za-z][A-Za-z0-9]*\}\}/g) ?? []).sort();
}

for (const [key, entry] of Object.entries(translations)) {
  if (!key.trim()) throw new Error("UI localization fragments contain an empty key");
  const actualLocales = Object.keys(entry).sort();
  if (JSON.stringify(actualLocales) !== JSON.stringify([...locales].sort())) {
    throw new Error(`${key} must contain exactly ${locales.join("/")}`);
  }
  for (const locale of locales) {
    if (typeof entry[locale] !== "string" || !entry[locale].trim()) {
      throw new Error(`${key} contains an empty/non-string ${locale} translation`);
    }
  }
  const expectedPlaceholders = placeholders(entry.en);
  for (const locale of locales.filter((locale) => locale !== "en")) {
    if (JSON.stringify(placeholders(entry[locale])) !== JSON.stringify(expectedPlaceholders)) {
      throw new Error(`${key} has mismatched placeholders in ${locale}`);
    }
  }
}

for (const file of swiftFiles) {
  const source = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file);
  const legacyPattern = /\blocalized\(\s*"(?:[^"\\]|\\.)*"\s*,\s*(?:"|default:|spanish:)/gs;
  for (const match of source.matchAll(legacyPattern)) {
    legacyCalls.push(`${relative}:${source.slice(0, match.index).split("\n").length}`);
  }
  const keyPattern = /\b(?:localized|localizedTemplate|localizedValueTemplate|localizedCountTemplate)\(\s*"((?:[^"\\]|\\.)*)"/gs;
  for (const match of source.matchAll(keyPattern)) {
    const key = match[1].replaceAll('\\"', '"').replaceAll("\\\\", "\\");
    referencedKeys.add(key);
    if (!translations[key]) {
      missingKeys.push(`${relative}:${source.slice(0, match.index).split("\n").length}: ${key}`);
    }
  }
  const secondCountKeyPattern = /\blocalizedCountTemplate\(\s*"(?:[^"\\]|\\.)*"\s*,\s*"((?:[^"\\]|\\.)*)"/gs;
  for (const match of source.matchAll(secondCountKeyPattern)) {
    const key = match[1].replaceAll('\\"', '"').replaceAll("\\\\", "\\");
    referencedKeys.add(key);
    if (!translations[key]) {
      missingKeys.push(`${relative}:${source.slice(0, match.index).split("\n").length}: ${key}`);
    }
  }
}

if (legacyCalls.length) {
  throw new Error(`Legacy inline localized() calls remain:\n${legacyCalls.join("\n")}`);
}
if (missingKeys.length) {
  throw new Error(`Swift references missing localization keys:\n${missingKeys.join("\n")}`);
}

const strings = {};
for (const [key, entry] of Object.entries(translations).sort(([a], [b]) => a.localeCompare(b))) {
  const localizations = {};
  for (const locale of locales) {
    localizations[catalogLocale[locale]] = {
      stringUnit: { state: "translated", value: entry[locale] },
    };
  }
  strings[key] = { extractionState: "manual", localizations };
}

const catalog = { sourceLanguage: "en", strings, version: "1.0" };
const serialized = `${JSON.stringify(catalog, null, 2)}\n`;

if (validateOnly) {
  if (!fs.existsSync(outputPath)) throw new Error(`Missing ${path.relative(root, outputPath)}`);
  const current = fs.readFileSync(outputPath, "utf8");
  if (current !== serialized) throw new Error("Localizable.xcstrings is stale; run npm run ios:localization:build");
} else {
  fs.writeFileSync(outputPath, serialized);
}

const stats = {
  fixedStrings: Object.keys(translations).length,
  referencedKeys: referencedKeys.size,
  locales: locales.map((locale) => catalogLocale[locale]),
  fragments: translationFiles.length,
};
process.stdout.write(`${JSON.stringify(stats)}\n`);
