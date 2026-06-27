'use client';

import { useState, useEffect } from 'react';

const STORAGE_KEY = 'librenotes_demo';

function makeId() {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

const SEED_NOTES = [
  {
    id: 'seed1',
    title: 'Welcome to LibreNotes',
    body: `# Welcome to LibreNotes

This is a **live demo** running entirely in your browser. Notes are saved in \`localStorage\` - nothing leaves your device here.

The real app syncs to *your own server* over an encrypted connection. No cloud, no accounts, no tracking.

---

## Features
- **End-to-end encrypted** - the server never sees your content
- **Offline-first** - works without internet
- **Self-hosted** - you own the data
- **Open source** - AGPLv3`,
    createdAt: Date.now() - 1000 * 60 * 5,
    pinned: true,
    color: null,
  },
  {
    id: 'seed2',
    title: 'Markdown cheatsheet',
    body: `## Headings
# H1
## H2
### H3

## Emphasis
**bold**, *italic*, ~~strikethrough~~

## Lists
- Item one
- Item two
  - Nested

1. First
2. Second

## Code
Inline \`code\` and blocks:

\`\`\`js
const greet = name => \`Hello, \${name}!\`;
\`\`\`

## Links & images
[LibreNotes on GitHub](https://github.com/Piliii/LibreNotes)

> Blockquotes look great too.`,
    createdAt: Date.now() - 1000 * 60 * 60,
    pinned: false,
    color: null,
  },
  {
    id: 'seed3',
    title: 'Shopping list',
    body: `- [ ] Milk
- [ ] Bread
- [ ] Eggs
- [x] Coffee ✓`,
    createdAt: Date.now() - 1000 * 60 * 60 * 3,
    pinned: false,
    color: '#1e3a5f',
  },
];

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return null;
}

function save(notes) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(notes));
  } catch (_) {}
}

export function useNotes() {
  const [notes, setNotes] = useState([]);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const stored = load();
    setNotes(stored ?? SEED_NOTES);
    setHydrated(true);
  }, []);

  function update(updatedNotes) {
    setNotes(updatedNotes);
    save(updatedNotes);
  }

  function createNote() {
    const note = {
      id: makeId(),
      title: '',
      body: '',
      createdAt: Date.now(),
      pinned: false,
      color: null,
    };
    const next = [note, ...notes];
    update(next);
    return note.id;
  }

  function updateNote(id, patch) {
    const next = notes.map(n => (n.id === id ? { ...n, ...patch } : n));
    update(next);
  }

  function deleteNote(id) {
    const next = notes.filter(n => n.id !== id);
    update(next);
    return next[0]?.id ?? null;
  }

  const sorted = [...notes].sort((a, b) => {
    if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
    return b.createdAt - a.createdAt;
  });

  return { notes: sorted, hydrated, createNote, updateNote, deleteNote };
}
