import pkg from "fs-extra";
const { readFile, outputFile, copy, ensureDir } = pkg;
import { glob } from "glob";
import matter from "gray-matter";
import { unified } from "unified";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";
import remarkRehype from "remark-rehype";
import rehypeSlug from "rehype-slug";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import rehypeStringify from "rehype-stringify";
import { escape as xmlEscape } from "html-escaper"; // used for RSS

const SRC_DIR = "content/posts";
const OUT_DIR = "dist";
const PUBLIC_DIR = "public";

/* -------- version injector for cache-busting -------- */
const VERSION = Date.now().toString();
const injectVersion = (html) => html.replaceAll("{{VERSION}}", VERSION);

/* -------- helpers -------- */
const readTpl = (p) => readFile(p, "utf8");

const compileMd = async (md) =>
  String(
    await unified()
      .use(remarkParse)
      .use(remarkGfm)
      .use(remarkRehype, { allowDangerousHtml: true })
      .use(rehypeSlug)
      .use(rehypeAutolinkHeadings, { behavior: "wrap" })
      .use(rehypeStringify, { allowDangerousHtml: true })
      .process(md)
  );

const htmlEscape = (s = "") =>
  String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");


// reading time (~200 wpm)
const estimateReadingTime = (md) => {
  const text = String(md)
    .replace(/```[\s\S]*?```/g, "")
    .replace(/<[^>]*>/g, "")
    .replace(/[#>*`_\-\[\]()]/g, " ");
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return { minutes: Math.max(1, Math.ceil(words / 200)), words };
};

// short excerpt (~160 chars)
const makeExcerpt = (md, max = 160) => {
  const text = String(md)
    .replace(/```[\s\S]*?```/g, "")
    .replace(/!\[[^\]]*]\([^)]+\)/g, "")
    .replace(/\[[^\]]*]\([^)]+\)/g, "")
    .replace(/[#>*`_\-\[\]()]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return text.length <= max ? text : text.slice(0, max).replace(/\s+\S*$/, "") + "…";
};

// Export or inject version into HTML templates
function injectVersion(html) {
  return html.replaceAll("{{VERSION}}", VERSION);
}

// safe date formatting
const formatDate = (d) => {
  if (!d) return { iso: "", label: "Unknown date" };
  const dt = new Date(d);
  if (isNaN(dt)) return { iso: "", label: String(d) };
  return { iso: dt.toISOString(), label: dt.toString() };
};

// compute ../../ prefix so assets/nav work from any depth
const pathPrefixFor = (slug) => {
  if (!slug) return ""; // homepage
  const depth = slug.split("/").length; // e.g. posts/hello-world -> 2
  return "../".repeat(depth);
};

// apply layout + inject PREFIX into partials
const applyLayout = ({ layout, header, footer, title, content, prefix = "" }) =>
  layout
    .replace("{{HEADER}}", header.replaceAll("{{PREFIX}}", prefix))
    .replace("{{FOOTER}}", footer.replaceAll("{{PREFIX}}", prefix))
    .replaceAll("{{TITLE}}", htmlEscape(title || ""))
    .replaceAll("{{PREFIX}}", prefix)
    .replace("{{CONTENT}}", content);

/* ---------- build pipeline ---------- */

(async () => {
  await ensureDir(OUT_DIR);
  await copy(PUBLIC_DIR, `${OUT_DIR}/`);

  const [layout, header, footer] = await Promise.all([
    readTpl("templates/layout.html"),
    readTpl("templates/partials/header.html"),
    readTpl("templates/partials/footer.html"),
  ]);

  const files = await glob(`${SRC_DIR}/**/*.md`);
  // Cache-busting version for favicon URLs, etc.
  const VERSION = Date.now().toString();
  const injectVersion = (html) => html.replaceAll("{{VERSION}}", VERSION);
  const posts = [];

  // build each post
  for (const file of files) {
    const raw = await readFile(file, "utf8");
    const { data, content } = matter(raw);
    const html = await compileMd(content);

    const slug =
      data.slug ||
      file
        .replace(SRC_DIR + "/", "")
        .replace(/\.md$/i, "")
        .replace(/[^a-z0-9/_-]+/gi, "-")
        .toLowerCase();

    const outPath = `${OUT_DIR}/${slug}/index.html`;
    const prefix = pathPrefixFor(slug);

    const { minutes } = estimateReadingTime(content);
    const { iso: dateISO, label: dateLabel } = formatDate(data.date);
    const author = data.author || "Justine Longla";

    const metaHtml = `
      <p class="post-meta">
        ${author ? `By ${htmlEscape(author)} · ` : ""}
        ${minutes} min read · <time datetime="${htmlEscape(dateISO)}">${htmlEscape(dateLabel)}</time>
      </p>
    `;

    const htmlWithMeta = `${metaHtml}\n${html}`;

/* ----- Posts index (/posts/) ----- */
await ensureDir(`${OUT_DIR}/posts`);
await outputFile(
  `${OUT_DIR}/posts/index.html`,
  injectVersion(
    applyLayout({
      layout,
      header,
      footer,
      title: "All Blog Posts",
      content: `<h1>All Blog Posts</h1><div class="posts-grid">${cardsHtml}</div>`,
      prefix: "../",
    })
  )
);
console.log("📝 Posts index generated → dist/posts/index.html");


/* ----- Homepage (/) ----- */
const homeCardsHtml = posts
  .slice()
  .sort((a, b) => new Date(b.date) - new Date(a.date))
  .map((p) => {
    // on the homepage we can link directly to `${p.slug}/`
    return `
      <article class="post-card">
        <div class="meta">${htmlEscape(p.author)} · ${p.minutes} min read · ${htmlEscape(p.date)}</div>
        <h2><a href="${p.slug}/">${htmlEscape(p.title)}</a></h2>
        <p class="excerpt">${htmlEscape(p.excerpt)}</p>
      </article>
    `;
  })
  .join("\n");

const indexHtml = applyLayout({
  layout,
  header,
  footer,
  title: "Home",
  content: `<h1>All Posts</h1><div class="posts-grid">${homeCardsHtml}</div>`,
  prefix: "", // homepage is at the root
});

await outputFile(`${OUT_DIR}/index.html`, injectVersion(indexHtml));
console.log("🏠 Homepage generated → dist/index.html");


/* ----- About (/about/) ----- */
await ensureDir(`${OUT_DIR}/about`);
await outputFile(
  `${OUT_DIR}/about/index.html`,
  injectVersion(
    applyLayout({
      layout,
      header,
      footer,
      title: "About",
      content: `
        <h1>About This Blog</h1>
        <p>Welcome to <strong>Jutellane Blog</strong> — a space where I explore Cloud, DevOps, AI, and Sustainability. 
        Every post is written with a focus on learning, innovation, and real-world application.</p>
        <p>This static site is generated with Node.js and Markdown, 
        emphasizing simplicity, performance, and accessibility.</p>
      `,
      prefix: "../",
    })
  )
);
console.log("👤 About page generated → dist/about/index.html");


  /* ----- Homepage (/) ----- */
  const homeCardsHtml = posts
    .slice()
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .map((p) => {
      // on the homepage we can link directly to `${p.slug}/`
      return `
        <article class="post-card">
          <div class="meta">${htmlEscape(p.author)} · ${p.minutes} min read · ${htmlEscape(p.date)}</div>
          <h2><a href="${p.slug}/">${htmlEscape(p.title)}</a></h2>
          <p class="excerpt">${htmlEscape(p.excerpt)}</p>
        </article>
      `;
    })
    .join("\n");

  const indexHtml = applyLayout({
    layout,
    header,
    footer,
    title: "Home",
    content: `<h1>All Posts</h1><div class="posts-grid">${homeCardsHtml}</div>`,
    prefix: "", // homepage is at the root
  });

  await outputFile(`${OUT_DIR}/index.html`, indexHtml);
  console.log("🏠 Homepage generated → dist/index.html");


  /* ----- About (/about/) ----- */
  await ensureDir(`${OUT_DIR}/about`);
  await outputFile(
    `${OUT_DIR}/about/index.html`,
    applyLayout({
      layout,
      header,
      footer,
      title: "About",
      content: `
        <h1>About This Blog</h1>
        <p>Welcome to <strong>Jutellane Blog</strong> — a space where I explore Cloud, DevOps, AI, and Sustainability. 
        Every post is written with a focus on learning, innovation, and real-world application.</p>
        <p>This static site is generated with Node.js and Markdown, 
        emphasizing simplicity, performance, and accessibility.</p>
      `,
      prefix: "../",
    })
  );
  console.log("👤 About page generated → dist/about/index.html");

  /* ----- RSS (/feed.xml) ----- */
  // Publish URL: set via env (Actions) or fallback to local preview
  const BASE_URL = process.env.SITE_URL || "http://127.0.0.1:3000";

  const rssItems = posts
    .map(
      (p) => `
    <item>
      <title>${xmlEscape(p.title)}</title>
      <link>${BASE_URL}/${p.slug}/</link>
      <description>${xmlEscape(p.excerpt)}</description>
      <pubDate>${new Date(p.date).toUTCString()}</pubDate>
    </item>`
    )
    .join("\n");

  const rssFeed = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
  <title>Jutellane Blog</title>
  <link>${BASE_URL}/</link>
  <description>Exploring Cloud, DevOps, AI &amp; Sustainability</description>
  <language>en</language>
  ${rssItems}
</channel>
</rss>`;

  await outputFile(`${OUT_DIR}/feed.xml`, rssFeed);
  console.log("🪶 RSS feed generated → dist/feed.xml");

  console.log("✅ Build complete");
})();
