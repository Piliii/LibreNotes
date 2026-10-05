'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { Palette, Archive, Trash2 } from 'lucide-react';
import { timeAgo } from './format';

// Same rotation the real app's color picker offers, cycled on each click
// instead of a full swatch popover (the marketing demo doesn't need one).
const COLOR_CYCLE = [null, '#3a2a1e', '#1e3a5f', '#2a1e3a', '#1e3a2a'];

function ToolButton({ onClick, title, active, children }) {
  return (
    <button
      onClick={onClick}
      title={title}
      aria-label={title}
      className="flex items-center justify-center rounded-full p-1.5 transition-colors hover:brightness-125"
      style={{ color: active ? 'var(--accent)' : 'var(--text-secondary)' }}
    >
      {children}
    </button>
  );
}

export default function NoteEditor({ note, onUpdate, onDelete, onArchive, onBack }) {
  const [title, setTitle] = useState(note?.title ?? '');
  const [body, setBody] = useState(note?.body ?? '');
  const saveTimer = useRef(null);

  useEffect(() => {
    setTitle(note?.title ?? '');
    setBody(note?.body ?? '');
  }, [note?.id]);

  const flush = useCallback((t, b) => {
    if (!note) return;
    onUpdate(note.id, { title: t, body: b });
  }, [note, onUpdate]);

  function handleTitle(e) {
    const t = e.target.value;
    setTitle(t);
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => flush(t, body), 500);
  }

  function handleBody(e) {
    const b = e.target.value;
    setBody(b);
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => flush(title, b), 500);
  }

  function cycleColor() {
    const i = COLOR_CYCLE.indexOf(note.color ?? null);
    onUpdate(note.id, { color: COLOR_CYCLE[(i + 1) % COLOR_CYCLE.length] });
  }

  if (!note) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <p className="text-sm" style={{ color: 'var(--text-secondary)' }}>
          Select a note or create one
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden transition-colors duration-300" style={{ background: note.color ?? 'var(--bg-base)' }}>
      {/* Toolbar */}
      <div
        className="flex items-center justify-between gap-3 border-b px-4 py-3"
        style={{ borderColor: 'var(--border)' }}
      >
        {onBack ? (
          <button
            onClick={onBack}
            className="flex items-center gap-1 text-sm md:hidden"
            style={{ color: 'var(--text-secondary)' }}
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d="M10 3L5 8l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Notes
          </button>
        ) : (
          <span className="text-xs" style={{ color: 'var(--text-secondary)' }}>
            Edited {timeAgo(note.updatedAt ?? note.createdAt)}
          </span>
        )}

        <div
          className="ml-auto flex items-center gap-0.5 rounded-full px-1 py-0.5"
          style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)', backdropFilter: 'blur(12px)' }}
        >
          <ToolButton title="Note color" onClick={cycleColor}>
            <Palette size={18} strokeWidth={1.8} />
          </ToolButton>
          <ToolButton title="Archive" onClick={() => onArchive(note.id)}>
            <Archive size={18} strokeWidth={1.8} />
          </ToolButton>
          <ToolButton title="Move to Trash" onClick={() => onDelete(note.id)}>
            <Trash2 size={18} strokeWidth={1.8} />
          </ToolButton>
        </div>
      </div>

      {/* Content */}
      <div className="flex flex-1 flex-col overflow-hidden p-6 gap-3">
        <input
          className="w-full bg-transparent text-3xl font-semibold outline-none placeholder:opacity-30 placeholder:font-normal"
          style={{ color: 'var(--text-primary)' }}
          aria-label="Note title"
          placeholder="Title"
          value={title}
          onChange={handleTitle}
        />
        <textarea
          className="flex-1 w-full resize-none bg-transparent text-sm leading-relaxed outline-none placeholder:opacity-30"
          style={{ color: 'var(--text-primary)' }}
          aria-label="Note body"
          placeholder="Start typing… markdown supported"
          value={body}
          onChange={handleBody}
        />
      </div>
    </div>
  );
}
