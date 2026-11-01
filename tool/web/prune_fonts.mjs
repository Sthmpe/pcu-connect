// Removes font families the app never uses from a Flutter web build. Flutter
// web downloads every font in FontManifest.json at startup, and
// lucide_icons_flutter declares seven families (about 1.3 MB) while the app
// only uses Lucide300. Usage: node tool/web/prune_fonts.mjs build/web
import fs from 'node:fs';
import path from 'node:path';

const dir = process.argv[2] || 'build/web';
const manifestPath = path.join(dir, 'assets', 'FontManifest.json');
const keepLucide = new Set(['packages/lucide_icons_flutter/Lucide300']);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

// Refuse to drop a family that the compiled app still references.
const mainJs = fs.readFileSync(path.join(dir, 'main.dart.js'), 'utf8');
const drop = manifest.filter((f) => f.family.startsWith('packages/lucide_icons_flutter/') && !keepLucide.has(f.family));
for (const f of drop) {
  const short = f.family.split('/').pop();
  if (new RegExp(`["']${short}["']`).test(mainJs)) {
    console.error(`Not pruning ${f.family}: the app references it.`);
    process.exit(1);
  }
}

let bytes = 0;
for (const f of drop) {
  for (const font of f.fonts) {
    const file = path.join(dir, 'assets', font.asset);
    if (fs.existsSync(file)) {
      bytes += fs.statSync(file).size;
      fs.rmSync(file);
    }
  }
}
const kept = manifest.filter((f) => !drop.includes(f));
fs.writeFileSync(manifestPath, JSON.stringify(kept));
console.log(`Pruned ${drop.length} unused font families (${Math.round(bytes / 1024)} KB): ${drop.map((f) => f.family.split('/').pop()).join(', ')}`);
console.log(`Fonts loaded at startup: ${kept.map((f) => f.family).join(', ')}`);
