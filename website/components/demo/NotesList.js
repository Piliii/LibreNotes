'use client';

import { useState } from 'react';
import { Search, MoreVertical, CloudCheck, Pin, Plus } from 'lucide-react';
import { snippet } from './format';

// Small uppercase section label ("PINNED" / "NOTES")
function SectionHeader({ children }) {
  return (
    <p
      className="px-1 pb-1.5 text-[10px] font-semibold uppercase tracking-widest"
      style={{ color: 'var(--text-secondary)', opacity: 0.6 }}
    >
      {children}
    </p>
  );
}

// Sidebar row (desktop)
function NoteRow({ note, active, onClick }) {
  return (
    <button
      onClick={onClick}
      className="w-full text-left rounded-xl p-3.5 transition-colors"
      style={{
        background: active ? 'var(--bg-elevated)' : 'var(--bg-surface)',
        borderLeft: active ? '3px solid var(--accent)' : '3px solid transparent',
      }}
    >
      <div className="flex items-center gap-1.5">
        <span
          className={note.title ? 'truncate text-sm font-medium' : 'line-clamp-2 flex-1 text-sm'}
          style={{ color: 'var(--text-primary)' }}
        >
          {note.title || snippet(note.body) || 'No additional text'}
        </span>
        {note.pinned && <Pin size={12} style={{ color: 'var(--accent)', opacity: 0.8, flexShrink: 0 }} />}
      </div>
      {note.title && (
        <p className="mt-0.5 text-xs truncate" style={{ color: 'var(--text-secondary)' }}>
          {snippet(note.body) || 'No additional text'}
        </p>
      )}
    </button>
  );
}

// Card (mobile grid)
function NoteCard({ note, onClick }) {
  return (
    <button
      onClick={onClick}
      className="relative text-left rounded-xl p-4 transition-colors hover:brightness-110"
      style={{
        background: note.color ?? 'var(--bg-surface)',
        minHeight: 120,
        borderLeft: note.pinned ? '3px solid var(--accent)' : '3px solid transparent',
      }}
    >
      {note.pinned && (
        <span className="absolute right-3 top-3">
          <Pin size={13} style={{ color: 'var(--accent)' }} />
        </span>
      )}
      <p className="text-sm font-semibold truncate pr-4" style={{ color: 'var(--text-primary)' }}>
        {note.title || 'Untitled'}
      </p>
      <p className="mt-2 text-xs leading-relaxed line-clamp-4" style={{ color: 'var(--text-secondary)' }}>
        {snippet(note.body) || 'No content'}
      </p>
    </button>
  );
}

export default function NotesList({ notes, selectedId, onSelect, onNew, view }) {
  const [query, setQuery] = useState('');
  const q = query.trim().toLowerCase();

  const filtered = q
    ? notes.filter(n => n.title.toLowerCase().includes(q) || n.body.toLowerCase().includes(q))
    : notes;

  const pinned = filtered.filter(n => n.pinned);
  const unpinned = filtered.filter(n => !n.pinned);
  const hasSections = !q && pinned.length > 0 && unpinned.length > 0;

  if (view === 'grid') {
    // Mobile: 2-column card grid
    return (
      <div className="flex flex-col h-full overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3">
          <span className="text-base font-semibold" style={{ color: 'var(--text-primary)' }}>
            Notes
          </span>
          <NewButton onClick={onNew} />
        </div>
        <div className="flex-1 overflow-y-auto px-4 pb-4 space-y-4">
          {hasSections ? (
            <>
              <div>
                <SectionHeader>Pinned</SectionHeader>
                <div className="grid grid-cols-2 gap-3">
                  {pinned.map(n => (
                    <NoteCard key={n.id} note={n} onClick={() => onSelect(n.id)} />
                  ))}
                </div>
              </div>
              <div>
                <SectionHeader>Notes</SectionHeader>
                <div className="grid grid-cols-2 gap-3">
                  {unpinned.map(n => (
                    <NoteCard key={n.id} note={n} onClick={() => onSelect(n.id)} />
                  ))}
                </div>
              </div>
            </>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              {filtered.map(n => (
                <NoteCard key={n.id} note={n} onClick={() => onSelect(n.id)} />
              ))}
            </div>
          )}
          {filtered.length === 0 && (
            <p className="text-sm text-center py-12" style={{ color: 'var(--text-secondary)' }}>
              {notes.length === 0 ? 'No notes yet. Create one!' : 'No notes match'}
            </p>
          )}
        </div>
      </div>
    );
  }

  // Desktop: sidebar list
  return (
    <div
      className="flex flex-col h-full overflow-hidden border-r"
      style={{ borderColor: 'var(--border)', width: 280, flexShrink: 0 }}
    >
      <div className="flex flex-col gap-3 px-3 pt-4 pb-3 border-b" style={{ borderColor: 'var(--border)' }}>
        <div className="flex items-center justify-between px-1">
          <span className="text-xl font-bold" style={{ color: 'var(--text-primary)' }}>
            Notes
          </span>
          <div className="flex items-center gap-3">
            <button style={{ color: 'var(--text-secondary)' }} title="More" aria-label="More options">
              <MoreVertical size={18} strokeWidth={1.8} />
            </button>
            <CloudCheck size={18} strokeWidth={1.8} style={{ color: '#4CAF50' }} />
          </div>
        </div>

        <div
          className="flex items-center gap-2 rounded-lg px-3 py-2 border"
          style={{ background: 'var(--bg-base)', borderColor: 'var(--border)', color: 'var(--text-secondary)' }}
        >
          <Search size={16} strokeWidth={1.8} />
          <input
            value={query}
            onChange={e => setQuery(e.target.value)}
            aria-label="Search notes"
            placeholder="Search notes…"
            className="w-full bg-transparent text-sm outline-none placeholder:opacity-70"
            style={{ color: 'var(--text-primary)' }}
          />
        </div>

        <button
          onClick={onNew}
          className="rounded-lg py-2.5 text-sm font-semibold transition-colors hover:brightness-90"
          style={{ background: 'var(--accent)', color: '#fff' }}
        >
          + New Note
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-2 space-y-3">
        {hasSections ? (
          <>
            <div>
              <SectionHeader>Pinned</SectionHeader>
              <div className="space-y-1.5">
                {pinned.map(n => (
                  <NoteRow key={n.id} note={n} active={n.id === selectedId} onClick={() => onSelect(n.id)} />
                ))}
              </div>
            </div>
            <div>
              <SectionHeader>Notes</SectionHeader>
              <div className="space-y-1.5">
                {unpinned.map(n => (
                  <NoteRow key={n.id} note={n} active={n.id === selectedId} onClick={() => onSelect(n.id)} />
                ))}
              </div>
            </div>
          </>
        ) : (
          <div className="space-y-1.5">
            {filtered.map(n => (
              <NoteRow key={n.id} note={n} active={n.id === selectedId} onClick={() => onSelect(n.id)} />
            ))}
          </div>
        )}
        {filtered.length === 0 && (
          <p className="text-xs text-center py-8" style={{ color: 'var(--text-secondary)' }}>
            {notes.length === 0 ? 'No notes yet' : 'No notes match'}
          </p>
        )}
      </div>
    </div>
  );
}

function NewButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      className="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-xs font-semibold transition-colors hover:brightness-90"
      style={{ background: 'var(--accent)', color: '#fff' }}
    >
      <Plus size={13} strokeWidth={2.2} />
      New
    </button>
  );
}
