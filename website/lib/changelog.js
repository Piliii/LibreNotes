'use client';

import { useEffect, useState } from 'react';

const CHANGELOG_URL = 'https://raw.githubusercontent.com/Piliii/LibreNotes/main/CHANGELOG.md';

// Module-level so every consumer on the page (nav badge, homepage section,
// popup, /changelog page) shares one fetch instead of firing four.
let cachedPromise = null;

function parseChangelog(text) {
  const headingRe = /^## \[([^\]]+)\](?:\s*[—-]\s*(\d{4}-\d{2}-\d{2}))?\s*$/gm;
  const matches = [...text.matchAll(headingRe)];
  const entries = [];

  for (let i = 0; i < matches.length; i++) {
    const match = matches[i];
    const version = match[1];
    const date = match[2] ?? null;
    const bodyStart = match.index + match[0].length;
    const bodyEnd = matches[i + 1]?.index ?? text.length;
    const body = text.slice(bodyStart, bodyEnd).trim();

    if (version.toLowerCase() === 'unreleased' || !body) continue;
    entries.push({ version, date, body });
  }

  return entries;
}

export function fetchChangelog() {
  if (!cachedPromise) {
    cachedPromise = fetch(CHANGELOG_URL)
      .then((res) => {
        if (!res.ok) throw new Error(`GitHub returned ${res.status}`);
        return res.text();
      })
      .then(parseChangelog)
      .catch((err) => {
        cachedPromise = null;
        throw err;
      });
  }
  return cachedPromise;
}

export function useChangelog() {
  const [state, setState] = useState({ loading: true, error: null, entries: [] });

  useEffect(() => {
    let alive = true;
    fetchChangelog()
      .then((entries) => alive && setState({ loading: false, error: null, entries }))
      .catch((error) => alive && setState({ loading: false, error, entries: [] }));
    return () => {
      alive = false;
    };
  }, []);

  return state;
}
