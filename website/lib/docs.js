import fs from 'node:fs';
import path from 'node:path';

// Sidebar order and grouping. Each entry maps a URL slug to a markdown file in
// content/docs/. Add a page by dropping a .md file there and listing it here.
export const DOCS = [
  { slug: 'introduction', title: 'Introduction', group: 'Getting started', file: 'introduction.md' },
  { slug: 'install', title: 'Install the app', group: 'Getting started', file: 'install.md' },
  { slug: 'sync-setup', title: 'Set up sync', group: 'Sync', file: 'sync-setup.md' },
  { slug: 'encryption', title: 'Encryption & privacy', group: 'Sync', file: 'encryption.md' },
  { slug: 'troubleshooting', title: 'Troubleshooting', group: 'Help', file: 'troubleshooting.md' },
];

const CONTENT_DIR = path.join(process.cwd(), 'content', 'docs');

export function getDoc(slug) {
  const index = DOCS.findIndex((d) => d.slug === slug);
  if (index === -1) return null;
  const entry = DOCS[index];
  return {
    ...entry,
    body: fs.readFileSync(path.join(CONTENT_DIR, entry.file), 'utf8'),
    prev: DOCS[index - 1] ?? null,
    next: DOCS[index + 1] ?? null,
  };
}

export function groupedDocs() {
  const groups = [];
  for (const doc of DOCS) {
    let g = groups.find((x) => x.name === doc.group);
    if (!g) groups.push((g = { name: doc.group, items: [] }));
    g.items.push(doc);
  }
  return groups;
}
