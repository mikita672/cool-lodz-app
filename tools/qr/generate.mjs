#!/usr/bin/env node
// Printable QR codes for the quest «Chłodne hasło» (APP-15): one A4 page per
// place with a QR for coollodz://quest/{placeId}?c={kod}, the place name and
// «Zeskanuj kod przy wejściu».
//
// The codes come from tools/qr/codes.json, written by the Firestore seed
// (tools/firestore-seed/seed.mjs). That file and the PDF are gitignored: a
// photo of a QR code is enough to collect points without visiting, so never
// commit or share them. After rotating the codes (seed --new-codes), run this
// again and reprint.
//
//   npm --prefix tools/qr ci
//   node tools/qr/generate.mjs [--codes tools/qr/codes.json] [--out tools/qr/out/quest-codes.pdf]
//       [--png docs/quest-qr]
//
// --png also writes one PNG per place (NN-placeId.png) and an index README
// into that folder. The team keeps them in docs/quest-qr/ for printing and
// the video: rotate the codes (seed --new-codes) when the quest goes live.
//
// The letter of each place is not printed: it would give the password away.
import {
  createWriteStream,
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

const { values: opts } = parseArgs({
  options: {
    codes: { type: 'string', default: 'tools/qr/codes.json' },
    out: { type: 'string', default: 'tools/qr/out/quest-codes.pdf' },
    png: { type: 'string' },
  },
});

function fail(message) {
  console.error(`qr: ${message}`);
  process.exit(1);
}

const codesPath = resolve(repoRoot, opts.codes);
if (!existsSync(codesPath)) {
  fail(`${codesPath} not found.\n` +
    '  Run the seed first (node tools/firestore-seed/seed.mjs, see docs/dev.md):\n' +
    '  it writes the codes to Firestore questCodes and to this file.');
}
const data = JSON.parse(readFileSync(codesPath, 'utf8'));
const places = [...(data.places ?? [])].sort((a, b) => a.order - b.order);
if (places.length === 0) fail(`no places in ${codesPath}`);

const LINK = /^coollodz:\/\/quest\/[A-Za-z0-9_-]+\?c=[A-Z0-9]+$/;
for (const p of places) {
  const link = p.link ?? `coollodz://quest/${p.placeId}?c=${p.code}`;
  if (!LINK.test(link)) fail(`bad link for ${p.placeId}: ${link}`);
  p.link = link;
}

const outPath = resolve(repoRoot, opts.out);
mkdirSync(dirname(outPath), { recursive: true });

// Inter from the app: the PDF base fonts have no Polish letters.
const fonts = resolve(repoRoot, 'assets/fonts');
const doc = new PDFDocument({ size: 'A4', margin: 56, autoFirstPage: false });
doc.registerFont('Inter', `${fonts}/Inter-Regular.ttf`);
doc.registerFont('Inter-Bold', `${fonts}/Inter-Bold.ttf`);
doc.registerFont('Inter-SemiBold', `${fonts}/Inter-SemiBold.ttf`);
const done = new Promise((ok, err) => {
  const stream = createWriteStream(outPath);
  stream.on('finish', ok);
  stream.on('error', err);
  doc.pipe(stream);
});

const PRIMARY = '#0E6E8C';
const TEXT = '#12232B';
const MUTED = '#4A5D66';

for (const [i, p] of places.entries()) {
  doc.addPage();
  const width = doc.page.width - 2 * 56;

  doc.font('Inter-Bold').fontSize(30).fillColor(PRIMARY)
    .text('Cool Łódź', { align: 'center', width });
  doc.moveDown(0.2);
  doc.font('Inter-SemiBold').fontSize(16).fillColor(MUTED)
    .text(`Quest «Chłodne hasło» · miejsce ${p.order} z ${places.length}`, {
      align: 'center',
      width,
    });

  const png = await QRCode.toBuffer(p.link, {
    errorCorrectionLevel: 'M',
    margin: 2,
    scale: 16,
    color: { dark: '#000000', light: '#FFFFFF' },
  });
  const size = 340;
  const x = (doc.page.width - size) / 2;
  const y = 190;
  doc.image(png, x, y, { width: size, height: size });

  doc.font('Inter-Bold').fontSize(26).fillColor(TEXT)
    .text('Zeskanuj kod przy wejściu', 56, y + size + 36, { align: 'center', width });
  doc.moveDown(0.4);
  doc.font('Inter-SemiBold').fontSize(18).fillColor(TEXT)
    .text(p.name ?? p.placeId, { align: 'center', width });
  doc.moveDown(0.8);
  doc.font('Inter').fontSize(12).fillColor(MUTED)
    .text('Otwórz aplikację Cool Łódź → Quest → «Skanuj kod QR». ' +
      'Kod działa tylko przy tym miejscu (do 150 m), raz dziennie.', {
      align: 'center',
      width,
    });

  doc.font('Inter').fontSize(9).fillColor(MUTED)
    .text(`${data.questId ?? 'quest'} · ${p.placeId} · ${i + 1}/${places.length}`,
      56, doc.page.height - 56 - 12, { align: 'center', width, lineBreak: false });
}

doc.end();
await done;
console.log(`qr: ${places.length} pages written to ${outPath}`);

if (opts.png) {
  const pngDir = resolve(repoRoot, opts.png);
  mkdirSync(pngDir, { recursive: true });
  const rows = [];
  for (const p of places) {
    const file = `${String(p.order).padStart(2, '0')}-${p.placeId}.png`;
    await QRCode.toFile(resolve(pngDir, file), p.link, {
      errorCorrectionLevel: 'M',
      margin: 4,
      width: 1024,
      color: { dark: '#000000', light: '#FFFFFF' },
    });
    rows.push(`| ${p.order} | ${p.name ?? p.placeId} | \`${p.placeId}\` | ![${p.placeId}](${file}) |`);
  }
  writeFileSync(
    resolve(pngDir, 'README.md'),
    [
      '# Quest QR codes («Chłodne hasło»)',
      '',
      'One code per quest place, in quest order. Print each one (at least 8 cm wide) and hang it at the public entrance of the place. The app accepts a scan only within 150 m of the place, once a day per player.',
      '',
      'Generated by `node tools/qr/generate.mjs --png docs/quest-qr` from the codes in Firestore `questCodes` (see docs/dev.md). The letters are not printed: they would give the password away.',
      '',
      '> These images are public in this repository, so anyone can scan them without visiting. Before the quest goes live for real users, rotate the codes (`node tools/firestore-seed/seed.mjs --new-codes …`) and print the new ones from the PDF instead.',
      '',
      '| # | Place | Id | QR |',
      '| --: | --- | --- | --- |',
      ...rows,
      '',
    ].join('\n'),
  );
  console.log(`qr: ${places.length} PNG files written to ${pngDir}`);
}
