#!/usr/bin/env node
// Project a raw Argent or Figma payload into the symmetric shape the
// simulator-engineer judge consumes. The script does projection only —
// no diffing, no thresholds, no judgment. The agent runs both halves
// and hands the two normalized JSON files to the judge alongside the
// raw screenshots.
//
// Usage:
//   node normalize.mjs argent <tree.json> [--viewport-pt WxH]   > app.json
//   node normalize.mjs figma  <meta.xml> <ctx.code>             > figma.json
//
// Output shape (stdout):
//   { frame?:    { width, height },                   ← screen size in pt
//     root:      <Node> }
//
//   <Node> = { id, name, text?,
//              frame?: { x, y, w, h },                ← screen-absolute pt
//              fill?, stroke?,                        ← advisory; judge
//              font?:  { family, weight, size, style? },  reads screenshot
//              children?: [<Node>] }
//
// `frame` is screen-absolute points on both sides — the only space the
// judge compares cross-side. If the projector cannot compute it (e.g.
// describe input without --viewport-pt), the field is omitted and the
// judge falls back to screenshots.
//
// `name`, `fill`, `stroke`, `font` are advisory metadata. The judge does
// not fire deltas on name or fill differences alone — designers and devs
// name things differently, and CSS-variable hex resolution drifts
// between rendering pipelines. Visual judgment from screenshots is the
// ground truth for those axes.

import { readFileSync } from 'node:fs';

const die = (msg, code = 2) => { process.stderr.write(msg + '\n'); process.exit(code); };

function main() {
  const argv = process.argv.slice(2);

  const flagIdx = argv.indexOf('--viewport-pt');
  let viewportPt = null;
  if (flagIdx !== -1) {
    const val = argv[flagIdx + 1];
    const m = val && val.match(/^(\d+)x(\d+)$/);
    if (!m) die(`--viewport-pt expects WxH (got ${val})`);
    viewportPt = { width: +m[1], height: +m[2] };
    argv.splice(flagIdx, 2);
  }

  const [kind, ...args] = argv;

  if (kind === 'argent') {
    if (args.length < 1) die('usage: normalize.mjs argent <tree.json> [--viewport-pt WxH]');
    const raw = JSON.parse(readFileSync(args[0], 'utf8'));
    process.stdout.write(JSON.stringify(projectArgent(raw, viewportPt), null, 2) + '\n');
  } else if (kind === 'figma') {
    if (args.length < 2) die('usage: normalize.mjs figma <meta.xml> <ctx.code>');
    const meta = readFileSync(args[0], 'utf8');
    const ctx  = readFileSync(args[1], 'utf8');
    process.stdout.write(JSON.stringify(projectFigma(meta, ctx), null, 2) + '\n');
  } else {
    die('usage: normalize.mjs argent <tree.json> [--viewport-pt WxH]\n       normalize.mjs figma <meta.xml> <ctx.code>');
  }
}

// ─── Argent projection ─────────────────────────────────────────────
// Two source shapes are supported:
//   • debugger-component-tree (preferred) — React fiber tree with
//     componentName, testID, parent-relative pt frame, inline style.
//   • describe (fallback) — accessibility tree with role, label, and
//     normalized 0..1 frame relative to the screen.
//
// Both are projected into the symmetric Node shape with `frame` in
// screen-absolute pt. Conversion path depends on the source.
function projectArgent(raw, viewportPt) {
  const root  = raw.root ?? raw.tree ?? raw;
  const tree  = walkArgent(root, 0);
  // describe input carries normalized 0..1 frames; multiply by the
  // simulator's pt viewport to land in the same space as Figma.
  // debugger-component-tree input is already in pt; sum parent offsets.
  if (tree) {
    const isNormalized = looksNormalized(tree);
    if (isNormalized && viewportPt) scaleNormalizedFrames(tree, viewportPt);
    else if (isNormalized && !viewportPt) stripFrames(tree); // honest omission
    else if (tree.frame) absolutizeFrames(tree, -tree.frame.x, -tree.frame.y);
  }
  return {
    ...(viewportPt ? { frame: { width: viewportPt.width, height: viewportPt.height } } : {}),
    root: tree,
  };
}

function walkArgent(node, idx) {
  if (!node || typeof node !== 'object') return null;
  const out = {
    id: String(node.id ?? node.testID ?? `argent-${idx}`),
    // Designer/dev naming diverges (Card vs ReviewCard, Button vs PrimaryCTA).
    // Name is advisory — the judge does not fire deltas on name alone.
    name: node.componentName ?? node.name ?? node.type ?? stripAx(node.role) ?? 'Unknown',
  };
  if (node.text  != null) out.text = String(node.text);
  else if (node.label != null) out.text = String(node.label);
  const f = node.frame ?? node.bounds ?? node.layout;
  if (f) {
    out.frame = {
      x: numeric(f.x),
      y: numeric(f.y),
      w: numeric(f.w ?? f.width),
      h: numeric(f.h ?? f.height),
    };
  }
  const style = node.style ?? {};
  if (style.backgroundColor) out.fill   = style.backgroundColor;
  if (style.borderColor)     out.stroke = style.borderColor;
  if (style.fontFamily || style.fontWeight || style.fontSize) {
    out.font = clean({
      family: style.fontFamily,
      weight: style.fontWeight,
      size:   style.fontSize,
    });
  }
  const kids = node.children ?? [];
  if (kids.length) {
    const projected = kids.map((c, i) => walkArgent(c, i)).filter(Boolean);
    if (projected.length) out.children = projected;
  }
  return out;
}

function stripAx(s) {
  return typeof s === 'string' ? s.replace(/^AX/, '') : s;
}

// All frame.{x,y,w,h} ≤ 1 → input is normalized fractions of screen.
function looksNormalized(node) {
  let allLe1 = true, sawFrame = false;
  (function walk(n) {
    if (n.frame) {
      sawFrame = true;
      const { x, y, w, h } = n.frame;
      if (x > 1 || y > 1 || w > 1 || h > 1) allLe1 = false;
    }
    (n.children ?? []).forEach(walk);
  })(node);
  return sawFrame && allLe1;
}

function scaleNormalizedFrames(node, vp) {
  if (node.frame) {
    node.frame = {
      x: round(node.frame.x * vp.width),
      y: round(node.frame.y * vp.height),
      w: round(node.frame.w * vp.width),
      h: round(node.frame.h * vp.height),
    };
  }
  (node.children ?? []).forEach(c => scaleNormalizedFrames(c, vp));
}

function stripFrames(node) {
  delete node.frame;
  (node.children ?? []).forEach(stripFrames);
}

// ─── Figma projection ──────────────────────────────────────────────
// Two passes:
//   1. Parse get_metadata XML → tree of { id, name, frame, children }.
//      Coordinates are parent-relative, matching RN's flex tree.
//   2. Parse get_design_context React+Tailwind → per-node enrichment
//      keyed by data-node-id. Merge by id into the metadata tree.
function projectFigma(metaXml, ctxCode) {
  const tree     = parseMetadata(metaXml);
  const enrichBy = parseDesignContext(ctxCode);
  const root     = mergeEnrichment(tree, enrichBy);
  const viewport = root?.frame ? { width: root.frame.w, height: root.frame.h } : null;
  // Anchor screen-absolute coords at (0,0). The root's metadata x/y
  // is its position on the Figma canvas, not on the screen — strip it
  // by passing its negation as the seed parent offset.
  if (root?.frame) absolutizeFrames(root, -root.frame.x, -root.frame.y);
  return {
    ...(viewport ? { frame: viewport } : {}),
    root,
  };
}

function parseMetadata(xml) {
  // Stack-based regex tokenizer. Figma's metadata XML is generated and
  // predictable: each element is `<tag attrs… />` or `<tag attrs…>…</tag>`.
  // No CDATA, no comments, no namespaces, no mixed content.
  const tokRe = /<(\/?)([\w-]+)((?:\s+[\w-]+="[^"]*")*)\s*(\/?)>/g;
  const sentinel = { children: [] };
  const stack = [sentinel];
  for (const m of xml.matchAll(tokRe)) {
    const [, slash, tag, attrStr, selfClose] = m;
    if (slash) { stack.pop(); continue; }
    const attrs = {};
    for (const a of attrStr.matchAll(/([\w-]+)="([^"]*)"/g)) attrs[a[1]] = a[2];
    const node = {
      id:   attrs.id,
      name: attrs.name ?? tag,
      frame: {
        x: numeric(attrs.x),
        y: numeric(attrs.y),
        w: numeric(attrs.width),
        h: numeric(attrs.height),
      },
      children: [],
    };
    stack[stack.length - 1].children.push(node);
    if (!selfClose) stack.push(node);
  }
  const dropEmptyChildren = n => {
    if (!n) return n;
    if (n.children?.length) n.children = n.children.map(dropEmptyChildren);
    else delete n.children;
    return n;
  };
  return dropEmptyChildren(sentinel.children[0] ?? null);
}

function parseDesignContext(code) {
  // Walk every JSX element carrying data-node-id and harvest:
  //   - text content (only when the element has no descendant carrying
  //     its own data-node-id — otherwise the text belongs to a child)
  //   - className tokens for fill / font / size / weight
  // Build { "<id>": { text?, fill?, stroke?, font? } }.
  const out = {};
  // Attribute span is constrained to [^<>] so the lazy matcher cannot
  // cross over an inner tag and bind itself to a later element's id.
  const tagRe = /<(\w+)([^<>]*?\bdata-node-id="([^"]+)"[^<>]*?)(\/?)>/g;
  let m;
  while ((m = tagRe.exec(code)) !== null) {
    const [, tag, attrs, id, selfClose] = m;
    const entry = (out[id] ??= {});
    enrichFromClassName(extractClassName(attrs), entry);
    if (!selfClose) {
      const innerEnd = findMatchingClose(code, tag, m.index + m[0].length);
      if (innerEnd >= 0) {
        const inner = code.slice(m.index + m[0].length, innerEnd);
        if (!/data-node-id="/.test(inner)) {
          const text = stripJsx(inner);
          if (text) entry.text = text;
        }
      }
    }
  }
  return out;
}

function findMatchingClose(code, tag, openEnd) {
  // Balance nested same-tag opens/closes from `openEnd` forward.
  const re = new RegExp(`<(/?)${tag}\\b(?:\\s[\\s\\S]*?)?(/?)>`, 'g');
  re.lastIndex = openEnd;
  let depth = 1;
  let m;
  while ((m = re.exec(code)) !== null) {
    const closing   = m[1] === '/';
    const selfClose = m[2] === '/';
    if (closing) {
      depth--;
      if (depth === 0) return m.index;
    } else if (!selfClose) {
      depth++;
    }
  }
  return -1;
}

function extractClassName(attrs) {
  const dq = attrs.match(/className="([^"]+)"/);
  if (dq) return dq[1];
  const tpl = attrs.match(/className=\{`([^`]+)`\}/);
  if (tpl) return tpl[1];
  return '';
}

// CSS named-color fallbacks that appear in Tailwind var() patterns.
// Anything outside this map is honestly omitted — partial fill data
// is worse than none because absent fields read as "not specified".
const NAMED_COLORS = {
  white:       '#ffffff',
  black:       '#000000',
  transparent: 'transparent',
  red:         '#ff0000',
  green:       '#008000',
  blue:        '#0000ff',
  gray:        '#808080',
  grey:        '#808080',
};

function resolveColor(token) {
  if (!token) return null;
  if (token.startsWith('#')) return token.toLowerCase();
  return NAMED_COLORS[token.toLowerCase()] ?? null;
}

function enrichFromClassName(cls, entry) {
  if (!cls) return;
  let m;
  // text-[color:var(--token,<fallback>)] — most common. Capture <fallback>.
  // text-[color:<value>] — direct hex or named color.
  if ((m = cls.match(/text-\[color:var\(--[^,)]+,([^)]+)\)\]/))
   || (m = cls.match(/text-\[color:(#[0-9a-fA-F]{3,8}|[a-zA-Z]+)\]/))) {
    const c = resolveColor(m[1]);
    if (c) entry.fill = c;
  }
  // bg-[var(--token,<fallback>)] / bg-[<value>] / bg-<name>
  if (!entry.fill) {
    if ((m = cls.match(/bg-\[var\(--[^,)]+,([^)]+)\)\]/))
     || (m = cls.match(/bg-\[(#[0-9a-fA-F]{3,8}|[a-zA-Z]+)\]/))) {
      const c = resolveColor(m[1]);
      if (c) entry.fill = c;
    } else if ((m = cls.match(/\bbg-(white|black|transparent|red|green|blue|gray|grey)\b/))) {
      entry.fill = NAMED_COLORS[m[1]];
    }
  }
  // font-['Family:Style',…]
  if ((m = cls.match(/font-\['([^':]+)(?::([^']+))?'/))) {
    entry.font ??= {};
    entry.font.family = m[1];
    if (m[2]) entry.font.style = m[2].replace(/_/g, ' ');
  }
  // font-(weight-token)
  if ((m = cls.match(/\bfont-(thin|extralight|light|normal|medium|semibold|bold|extrabold|black)\b/))) {
    const weights = { thin: 100, extralight: 200, light: 300, normal: 400,
                      medium: 500, semibold: 600, bold: 700, extrabold: 800, black: 900 };
    entry.font ??= {};
    entry.font.weight = weights[m[1]];
  }
  // text-[Npx]
  if ((m = cls.match(/text-\[(\d+(?:\.\d+)?)px\]/))) {
    entry.font ??= {};
    entry.font.size = parseFloat(m[1]);
  }
}

function stripJsx(html) {
  return html
    .replace(/\{[^{}]*\}/g, '')
    .replace(/<[^>]+>/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function mergeEnrichment(node, byId) {
  if (!node) return node;
  const enr = node.id ? byId[node.id] : null;
  if (enr) {
    if (enr.text   != null) node.text   = enr.text;
    if (enr.fill)           node.fill   = enr.fill;
    if (enr.stroke)         node.stroke = enr.stroke;
    if (enr.font)           node.font   = clean(enr.font);
  }
  if (node.children) node.children = node.children.map(c => mergeEnrichment(c, byId));
  return node;
}

// ─── helpers ───────────────────────────────────────────────────────
function numeric(v) {
  if (v == null || v === '') return 0;
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : 0;
}

function round(n) {
  return Math.round(n * 100) / 100;
}

function clean(obj) {
  const out = {};
  for (const k of Object.keys(obj)) if (obj[k] != null) out[k] = obj[k];
  return out;
}

// Walk the tree and replace each frame.{x,y} with its screen-absolute
// position (sum of parent offsets). Width and height stay as-is.
// Called after parseMetadata (Figma) and before output, and on Argent
// debugger-component-tree input where frames are parent-relative pt.
function absolutizeFrames(node, parentX, parentY) {
  if (!node) return;
  if (node.frame) {
    const ax = round(parentX + node.frame.x);
    const ay = round(parentY + node.frame.y);
    node.frame = { x: ax, y: ay, w: round(node.frame.w), h: round(node.frame.h) };
    (node.children ?? []).forEach(c => absolutizeFrames(c, ax, ay));
  } else {
    (node.children ?? []).forEach(c => absolutizeFrames(c, parentX, parentY));
  }
}

main();
