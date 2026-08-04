// Rydlnk transactional email system.
//
// Every email the platform sends is composed here so they share one voice and
// one set of brand tokens. Callers describe an email as content — a heading, a
// few blocks, at most one action — and get back both an HTML and a plain-text
// rendering.
//
// The HTML is deliberately unfashionable: nested presentational tables, inline
// styles, no shorthand properties, no flexbox or grid. That is not caution for
// its own sake. Outlook renders through Word's layout engine, which supports
// none of the above, and Gmail strips <style> blocks in a forwarded message.
// The layout has to survive without them.
//
// Three things do live in <style> because they can only degrade, never break:
// the dark-mode overrides, the small-screen stacking, and the link colour reset.
// Anything load-bearing is inlined on the element itself.

// ── Brand ───────────────────────────────────────────────────────────────────
// Mirrors src/app/globals.css. Duplicated rather than imported because edge
// functions run in Deno with no access to the Next.js build — if a token
// changes there, change it here.

export const brand = {
  ink: '#07231a',
  forest: '#0e3a2b',
  signal: '#12833f',
  signalDim: '#0d6330',
  /** Links on a dark surface. `signal` is a button colour and goes muddy there. */
  signalBright: '#1fb552',
  paper: '#edf1ee',
  shell: '#f7f9f7',
  white: '#ffffff',
  line: '#dde5e0',
  lineStrong: '#748981',
  muted: '#5c7268',
  amber: '#ffc531',
  amberDim: '#8a5e00',
  flag: '#a03d1b',
  // Dark-mode surfaces. The brand greens are dark already, so the dark theme
  // lifts the surface rather than inverting the palette.
  darkSurface: '#0b1d16',
  darkCard: '#12291f',
  darkLine: '#1e4c3a',
  darkText: '#e8f0eb',
  darkMuted: '#8fb0a2',
} as const;

const FONT =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif";
const MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace";

// ── Content model ───────────────────────────────────────────────────────────

export type Block =
  | { kind: 'text'; text: string }
  /** Label/value rows. Used for receipts and statement summaries. */
  | { kind: 'facts'; rows: Array<[string, string]>; total?: [string, string] }
  /** Tinted panel for the one thing that must not be missed. */
  | { kind: 'callout'; tone: 'neutral' | 'warning' | 'positive'; title?: string; text: string }
  | { kind: 'bullets'; items: string[] }
  /** Monospaced fallback for a link, so a dead button is never a dead end. */
  | { kind: 'link-fallback'; url: string }
  /** A one-time code, sized and spaced to be copied by hand without misreading. */
  | { kind: 'code'; label?: string; value: string }
  | { kind: 'divider' };

export type EmailSpec = {
  /** Inbox preview line. Without it clients scrape the first body text. */
  preheader: string;
  heading: string;
  /** Sits under the heading in a lighter weight. */
  subheading?: string;
  blocks: Block[];
  /**
   * The single action. A copyable form of the same URL is rendered directly
   * beneath it — corporate mail clients strip or rewrite button hrefs often
   * enough that a button alone is not a reliable way to deliver a link. Set
   * `fallback: false` for a URL that is not worth the extra weight.
   */
  cta?: { label: string; url: string; fallback?: boolean };
  /** Small print under the divider. Rendered as HTML — escape interpolations. */
  footnote?: string;
  /** Overrides the default "you received this because…" line. Plain text. */
  footerReason?: string;
};

export type RenderedEmail = { subject?: string; html: string; text: string };

// ── Escaping ────────────────────────────────────────────────────────────────

const ENTITIES: Record<string, string> = {
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
};

export function escapeHtml(value: string): string {
  return String(value).replace(/[&<>"']/g, (c) => ENTITIES[c]);
}

/**
 * Escapes a URL for an href.
 *
 * Attribute escaping alone is not enough here: `javascript:` and `data:` URLs
 * survive it intact. Company names and site origins both reach this from
 * outside, so anything that is not http(s) collapses to '#'.
 */
export function escapeUrl(value: string): string {
  const raw = String(value).trim();
  if (!/^https?:\/\//i.test(raw)) return '#';
  return escapeHtml(raw);
}

// ── Building blocks ─────────────────────────────────────────────────────────

const td = (style: string, content: string) => `<td style="${style}">${content}</td>`;

/** One full-width presentational row. Every block is one of these. */
function row(content: string, padding = '0 40px'): string {
  return `<tr>${td(`padding:${padding};`, content)}</tr>`;
}

function textBlock(text: string): string {
  return row(
    `<p class="rl-body" style="margin:0 0 18px;font-family:${FONT};font-size:16px;line-height:1.6;color:${brand.ink};">${text}</p>`,
  );
}

function factsBlock(rows: Array<[string, string]>, total?: [string, string]): string {
  const body = rows
    .map(
      ([label, value]) => `
      <tr>
        <td class="rl-muted" style="padding:9px 0;font-family:${FONT};font-size:14px;line-height:1.5;color:${brand.muted};">${escapeHtml(label)}</td>
        <td class="rl-body" align="right" style="padding:9px 0;font-family:${FONT};font-size:14px;line-height:1.5;color:${brand.ink};font-weight:600;white-space:nowrap;">${escapeHtml(value)}</td>
      </tr>`,
    )
    .join('');

  // Border-top on the cells rather than the row: Outlook drops row borders.
  const totalRow = total
    ? `
      <tr>
        <td class="rl-body rl-total" style="padding:14px 0 0;border-top:1px solid ${brand.line};font-family:${FONT};font-size:15px;line-height:1.5;color:${brand.ink};font-weight:700;">${escapeHtml(total[0])}</td>
        <td class="rl-body rl-total" align="right" style="padding:14px 0 0;border-top:1px solid ${brand.line};font-family:${FONT};font-size:15px;line-height:1.5;color:${brand.ink};font-weight:700;white-space:nowrap;">${escapeHtml(total[1])}</td>
      </tr>`
    : '';

  return row(`
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="rl-panel" style="width:100%;margin:0 0 20px;background-color:${brand.shell};border:1px solid ${brand.line};border-radius:12px;">
      <tr><td style="padding:6px 20px 16px;">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;">
          ${body}${totalRow}
        </table>
      </td></tr>
    </table>`);
}

function calloutBlock(tone: 'neutral' | 'warning' | 'positive', title: string | undefined, text: string): string {
  const tones = {
    neutral:  { bg: brand.shell,   bar: brand.lineStrong, fg: brand.ink },
    warning:  { bg: '#fff8e6',     bar: brand.amber,      fg: brand.amberDim },
    positive: { bg: '#eaf5ee',     bar: brand.signal,     fg: brand.signalDim },
  }[tone];

  // Left rule as its own 4px cell — border-left on a padded cell is unreliable
  // across Outlook versions.
  return row(`
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="rl-callout" style="width:100%;margin:0 0 20px;background-color:${tones.bg};border-radius:10px;">
      <tr>
        <td width="4" style="width:4px;background-color:${tones.bar};border-radius:10px 0 0 10px;font-size:0;line-height:0;">&nbsp;</td>
        <td style="padding:14px 18px;">
          ${title ? `<p style="margin:0 0 5px;font-family:${FONT};font-size:14px;font-weight:700;line-height:1.4;color:${tones.fg};">${escapeHtml(title)}</p>` : ''}
          <p class="rl-callout-text" style="margin:0;font-family:${FONT};font-size:14px;line-height:1.55;color:${tone === 'neutral' ? brand.muted : tones.fg};">${text}</p>
        </td>
      </tr>
    </table>`);
}

function bulletsBlock(items: string[]): string {
  // Table rows, not <ul>: Outlook adds unpredictable margins to lists.
  const rows = items
    .map(
      (item) => `
      <tr>
        <td width="18" valign="top" style="width:18px;padding:0 0 9px;font-family:${FONT};font-size:16px;line-height:1.6;color:${brand.signal};">&bull;</td>
        <td class="rl-body" valign="top" style="padding:0 0 9px;font-family:${FONT};font-size:15px;line-height:1.6;color:${brand.ink};">${item}</td>
      </tr>`,
    )
    .join('');
  return row(`<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;margin:0 0 18px;">${rows}</table>`);
}

function linkFallbackBlock(url: string): string {
  const safe = escapeUrl(url);
  return row(`
    <p class="rl-muted" style="margin:0 0 6px;font-family:${FONT};font-size:13px;line-height:1.5;color:${brand.muted};">Or paste this into your browser:</p>
    <p style="margin:0 0 20px;font-family:${MONO};font-size:12px;line-height:1.5;word-break:break-all;">
      <a class="rl-link" href="${safe}" style="color:${brand.signal};text-decoration:underline;">${escapeHtml(url)}</a>
    </p>`);
}

/**
 * One-time code.
 *
 * Monospaced and letter-spaced on purpose: in a proportional face 0/O and 1/l
 * are ambiguous at exactly the moment someone is copying digits by hand.
 * `user-select: all` makes one tap select the whole code on mobile.
 */
function codeBlock(label: string | undefined, value: string): string {
  return row(`
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="rl-panel" style="width:100%;margin:0 0 20px;background-color:${brand.shell};border:1px solid ${brand.line};border-radius:12px;">
      <tr><td align="center" style="padding:18px 20px;">
        ${label ? `<p class="rl-muted" style="margin:0 0 8px;font-family:${FONT};font-size:12px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:${brand.muted};">${escapeHtml(label)}</p>` : ''}
        <p class="rl-body" style="margin:0;font-family:${MONO};font-size:30px;font-weight:700;letter-spacing:0.22em;line-height:1.2;color:${brand.ink};-webkit-user-select:all;user-select:all;">${escapeHtml(value)}</p>
      </td></tr>
    </table>`);
}

function dividerBlock(): string {
  return row(`<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;margin:6px 0 22px;"><tr><td class="rl-rule" style="height:1px;background-color:${brand.line};font-size:0;line-height:0;">&nbsp;</td></tr></table>`);
}

/**
 * Pill button.
 *
 * The VML branch is what makes it render in Outlook 2007–2019, which ignores
 * padding and background-color on an anchor. `v-text-anchor:middle` plus an
 * explicit height is the only combination that centres reliably there.
 */
function ctaBlock(label: string, url: string): string {
  const safe = escapeUrl(url);
  const text = escapeHtml(label);
  return row(`
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:4px 0 24px;">
      <tr><td align="center" style="border-radius:999px;background-color:${brand.signal};">
        <!--[if mso]>
        <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word"
          href="${safe}" style="height:50px;v-text-anchor:middle;width:280px;" arcsize="50%" stroke="f" fillcolor="${brand.signal}">
          <w:anchorlock/>
          <center style="color:#ffffff;font-family:${FONT};font-size:16px;font-weight:600;">${text}</center>
        </v:roundrect>
        <![endif]-->
        <!--[if !mso]><!-- -->
        <a href="${safe}" style="display:inline-block;padding:15px 34px;font-family:${FONT};font-size:16px;font-weight:600;line-height:1;color:#ffffff;text-decoration:none;border-radius:999px;background-color:${brand.signal};">${text}</a>
        <!--<![endif]-->
      </td></tr>
    </table>`);
}

function renderBlock(block: Block): string {
  switch (block.kind) {
    case 'text':          return textBlock(block.text);
    case 'facts':         return factsBlock(block.rows, block.total);
    case 'callout':       return calloutBlock(block.tone, block.title, block.text);
    case 'bullets':       return bulletsBlock(block.items);
    case 'link-fallback': return linkFallbackBlock(block.url);
    case 'code':          return codeBlock(block.label, block.value);
    case 'divider':       return dividerBlock();
  }
}

// ── Plain text ──────────────────────────────────────────────────────────────
// Not an afterthought: a message with no text/plain part is scored as spam by
// most filters, and the invite is the first mail a new domain ever sends.

const stripTags = (html: string) =>
  html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t]+/g, ' ')
    .trim();

function blockText(block: Block): string {
  switch (block.kind) {
    case 'text':
      return stripTags(block.text);
    case 'facts': {
      const width = Math.max(...block.rows.map(([l]) => l.length), block.total?.[0].length ?? 0);
      const lines = block.rows.map(([l, v]) => `  ${l.padEnd(width)}   ${v}`);
      if (block.total) {
        lines.push(`  ${'-'.repeat(width + 12)}`);
        lines.push(`  ${block.total[0].padEnd(width)}   ${block.total[1]}`);
      }
      return lines.join('\n');
    }
    case 'callout':
      return [block.title ? `[ ${block.title} ]` : null, stripTags(block.text)]
        .filter(Boolean).join('\n');
    case 'bullets':
      return block.items.map((i) => `  - ${stripTags(i)}`).join('\n');
    case 'link-fallback':
      return block.url;
    case 'code':
      // Spaced out in text too: the code is the payload of this email, and a
      // run-together string is the thing people mistype.
      return [block.label ? `${block.label}:` : null, `    ${block.value.split('').join(' ')}`]
        .filter(Boolean).join('\n');
    case 'divider':
      return '---';
  }
}

// ── Document ────────────────────────────────────────────────────────────────

export function renderEmail(spec: EmailSpec): RenderedEmail {
  const reason = spec.footerReason ??
    'You received this because your work email is part of a company using Rydlnk for staff transport.';

  const blocks = spec.blocks.map(renderBlock).join('\n');

  // The fallback is emitted here rather than left to the caller as a block, so
  // that it always lands *under* the button. As a block it sorted above the CTA
  // and the reader met "or paste this into your browser" before the thing it
  // was an alternative to.
  const cta = spec.cta
    ? ctaBlock(spec.cta.label, spec.cta.url) +
      (spec.cta.fallback === false ? '' : linkFallbackBlock(spec.cta.url))
    : '';

  const html = `<!doctype html>
<html lang="en" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="format-detection" content="telephone=no,address=no,email=no,date=no">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<title>${escapeHtml(spec.heading)}</title>
<!--[if mso]>
<noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
<![endif]-->
<style>
  /* Everything here is an enhancement. The inlined styles above already
     produce a correct light-mode layout on their own. */
  body { margin:0; padding:0; width:100% !important; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%; }
  table { border-collapse:collapse !important; mso-table-lspace:0pt; mso-table-rspace:0pt; }
  img { border:0; outline:none; line-height:100%; -ms-interpolation-mode:bicubic; }

  /* iOS turns anything address-like into a blue link regardless of the
     format-detection meta, so the colour is forced back. */
  a[x-apple-data-detectors] { color:inherit !important; text-decoration:none !important; font-size:inherit !important; font-family:inherit !important; font-weight:inherit !important; line-height:inherit !important; }

  @media only screen and (max-width:620px) {
    .rl-shell { padding:16px 0 !important; }
    .rl-pad { padding-left:24px !important; padding-right:24px !important; }
    .rl-h1 { font-size:24px !important; }
    .rl-card { border-radius:0 !important; border-left:0 !important; border-right:0 !important; }
  }

  @media (prefers-color-scheme: dark) {
    .rl-shell-bg { background-color:${brand.darkSurface} !important; }
    .rl-card { background-color:${brand.darkCard} !important; border-color:${brand.darkLine} !important; }
    .rl-h1, .rl-body, .rl-total { color:${brand.darkText} !important; }
    .rl-muted, .rl-sub, .rl-footer { color:${brand.darkMuted} !important; }
    .rl-panel { background-color:${brand.darkSurface} !important; border-color:${brand.darkLine} !important; }
    .rl-rule { background-color:${brand.darkLine} !important; }
    .rl-wordmark { color:${brand.darkText} !important; }
    /* The button keeps the signal green — it sits on its own fill. A bare
       link does not, and signal on the dark surface falls under 3:1. */
    .rl-link { color:${brand.signalBright} !important; }
  }
</style>
</head>
<body class="rl-shell-bg" style="margin:0;padding:0;background-color:${brand.paper};">

<!-- Preheader. Zero-size and colour-matched so it never renders in the body,
     followed by wide joiners so the client cannot pull body text in after it. -->
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;color:transparent;">
  ${escapeHtml(spec.preheader)}${'&#8199;&#65279;&#847; '.repeat(30)}
</div>

<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="rl-shell-bg" style="width:100%;background-color:${brand.paper};">
  <tr><td class="rl-shell" align="center" style="padding:32px 12px;">

    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:600px;max-width:600px;">

      <!-- Wordmark -->
      <tr><td class="rl-pad" style="padding:0 40px 18px;">
        <span class="rl-wordmark" style="font-family:${FONT};font-size:19px;font-weight:800;letter-spacing:-0.02em;color:${brand.forest};">Rydlnk</span>
      </td></tr>

      <tr><td>
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="rl-card" style="width:100%;background-color:${brand.white};border:1px solid ${brand.line};border-radius:14px;">

          <!-- Signal rule along the top edge -->
          <tr><td style="height:3px;background-color:${brand.signal};border-radius:14px 14px 0 0;font-size:0;line-height:0;">&nbsp;</td></tr>

          <tr><td class="rl-pad" style="padding:34px 40px 0;">
            <h1 class="rl-h1" style="margin:0;font-family:${FONT};font-size:27px;font-weight:800;line-height:1.22;letter-spacing:-0.025em;color:${brand.ink};">${escapeHtml(spec.heading)}</h1>
            ${spec.subheading ? `<p class="rl-sub" style="margin:9px 0 0;font-family:${FONT};font-size:16px;line-height:1.55;color:${brand.muted};">${escapeHtml(spec.subheading)}</p>` : ''}
          </td></tr>

          <tr><td style="height:22px;font-size:0;line-height:0;">&nbsp;</td></tr>

          ${blocks}
          ${cta}

          ${spec.footnote ? `
          <tr><td class="rl-pad" style="padding:0 40px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="width:100%;"><tr><td class="rl-rule" style="height:1px;background-color:${brand.line};font-size:0;line-height:0;">&nbsp;</td></tr></table>
            <p class="rl-muted" style="margin:16px 0 0;font-family:${FONT};font-size:13px;line-height:1.55;color:${brand.muted};">${spec.footnote}</p>
          </td></tr>` : ''}

          <tr><td style="height:34px;font-size:0;line-height:0;">&nbsp;</td></tr>
        </table>
      </td></tr>

      <tr><td class="rl-pad" style="padding:20px 40px 0;">
        <p class="rl-footer" style="margin:0 0 5px;font-family:${FONT};font-size:12px;line-height:1.55;color:${brand.muted};">${escapeHtml(reason)}</p>
        <p class="rl-footer" style="margin:0;font-family:${FONT};font-size:12px;line-height:1.55;color:${brand.muted};">Rydlnk &middot; Employer-funded staff transport</p>
      </td></tr>

    </table>
  </td></tr>
</table>
</body>
</html>`;

  // ── Text alternative ──
  const textParts = [
    spec.heading,
    '='.repeat(Math.min(spec.heading.length, 64)),
    spec.subheading ?? '',
    '',
    ...spec.blocks.map(blockText),
  ];
  if (spec.cta) textParts.push('', `${spec.cta.label}:`, spec.cta.url);
  if (spec.footnote) textParts.push('', stripTags(spec.footnote));
  textParts.push('', '—', reason, 'Rydlnk · Employer-funded staff transport');

  const text = textParts
    .filter((part, i, all) => !(part === '' && all[i - 1] === ''))
    .join('\n')
    .trim();

  return { html, text };
}

// Delivery lives in ./resend.ts. Keeping this module free of Deno globals is
// what lets the preview generator and the auth-template build import it under
// Node — the templates are then provably the same layout as the mail the edge
// functions send, rather than a copy that drifts.

// ── Formatting helpers ──────────────────────────────────────────────────────

export function formatMoney(cents: number, currency = 'usd'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency.toUpperCase(),
    minimumFractionDigits: 2,
  }).format(cents / 100);
}

export function formatCredits(credits: number): string {
  return `${new Intl.NumberFormat('en-US').format(credits)} credit${credits === 1 ? '' : 's'}`;
}

export function formatDate(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC',
  }).format(date);
}

/** Emphasis inside a body string. Escapes first, so callers may pass raw input. */
export function strong(value: string): string {
  return `<strong style="font-weight:600;color:inherit;">${escapeHtml(value)}</strong>`;
}
