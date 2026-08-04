// Syntax and import check for the Deno edge functions.
//
// These are excluded from `tsc --noEmit` — they import from URLs and use the
// Deno global, neither of which the Next.js tsconfig can resolve — so nothing
// in `npm run check` looked at them at all. A stray backtick inside one of the
// HTML template literals in _shared/email.ts is a syntax error that would not
// surface until `supabase functions deploy` rejected it, or worse, until the
// function 500ed in production.
//
// This is not a substitute for `deno check`. It parses with the TypeScript
// compiler and resolves relative imports; it does not typecheck across the URL
// imports. Run `deno check supabase/functions/**/*.ts` too where Deno exists.

const ts = require('typescript');
const { readFileSync, existsSync, readdirSync, statSync } = require('node:fs');
const { join, dirname, resolve } = require('node:path');

const ROOT = join(__dirname, '..', 'supabase', 'functions');

function walk(dir) {
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) return walk(full);
    return full.endsWith('.ts') ? [full] : [];
  });
}

const files = walk(ROOT).sort();
let failures = 0;

for (const file of files) {
  const rel = file.slice(join(__dirname, '..').length + 1);
  const source = readFileSync(file, 'utf8');
  const sf = ts.createSourceFile(file, source, ts.ScriptTarget.ES2022, true, ts.ScriptKind.TS);
  const problems = [];

  for (const d of sf.parseDiagnostics ?? []) {
    const { line, character } = sf.getLineAndCharacterOfPosition(d.start);
    problems.push(`${line + 1}:${character + 1}  ${ts.flattenDiagnosticMessageText(d.messageText, ' ')}`);
  }

  // Relative imports must carry the .ts extension and point at a real file:
  // Deno does not resolve extensionless specifiers, so an import that Node or
  // a bundler would forgive fails at deploy.
  const visit = (node) => {
    const spec =
      (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) && node.moduleSpecifier
        ? node.moduleSpecifier.text
        : null;
    if (spec && spec.startsWith('.')) {
      if (!spec.endsWith('.ts')) {
        problems.push(`import "${spec}" needs an explicit .ts extension for Deno`);
      } else if (!existsSync(resolve(dirname(file), spec))) {
        problems.push(`import "${spec}" does not resolve`);
      }
    }
    ts.forEachChild(node, visit);
  };
  visit(sf);

  if (problems.length) {
    failures++;
    console.log(`[31m✗[0m ${rel}`);
    for (const p of problems.slice(0, 8)) console.log(`    ${p}`);
  } else {
    console.log(`[32m✓[0m ${rel}`);
  }
}

if (failures) {
  console.log(`\n[31m${failures} file(s) failed[0m`);
  process.exit(1);
}
console.log(`\n[32mall ${files.length} edge function files parsed[0m`);
