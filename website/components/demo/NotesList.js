'use client';

function snippet(body) {
  const plain = body.replace(/[#*`~_\[\]>]/g, '').replace(/\n+/g, ' ').trim();
  return plain.length > 120 ? plain.slice(0, 120) + '…' : plain;
}

function timeAgo(ts) {
  const diff = Date.now() - ts;
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}

// Sidebar row (desktop)
function NoteRow({ note, active, onClick }) {
  return (
    <button
      onClick={onClick}
      className="w-full text-left px-3 py-3 rounded-lg transition-colors"
      style={{
        background: active ? 'var(--bg-elevated)' : 'transparent',
        borderLeft: active ? '3px solid var(--accent)' : '3px solid transparent',
      }}
    >
      <div className="flex items-center gap-1.5">
        {note.pinned && (
          <svg width="10" height="10" viewBox="0 0 10 10" fill="var(--accent)">
            <path d="M5 0l1.2 3.5H10L7.1 5.7l1.1 3.5L5 7.5l-3.2 1.7 1.1-3.5L0 3.5h3.8z" />
          </svg>
        )}
        <span
          className="truncate text-sm font-medium"
          style={{ color: note.title ? 'var(--text-primary)' : 'var(--text-secondary)' }}
        >
          {note.title || 'Untitled'}
        </span>
      </div>
      <p className="mt-0.5 text-xs truncate" style={{ color: 'var(--text-secondary)' }}>
        {snippet(note.body) || 'No content'}
      </p>
      <p className="mt-1 text-[10px]" style={{ color: 'var(--text-secondary)', opacity: 0.6 }}>
        {timeAgo(note.createdAt)}
      </p>
    </button>
  );
}

// Card (mobile grid)
function NoteCard({ note, onClick }) {
  return (
    <button
      onClick={onClick}
      className="text-left rounded-xl p-4 transition-colors hover:brightness-110"
      style={{ background: note.color ?? 'var(--bg-surface)', minHeight: 120 }}
    >
      <p className="text-sm font-semibold truncate" style={{ color: 'var(--text-primary)' }}>
        {note.title || 'Untitled'}
      </p>
      <p className="mt-2 text-xs leading-relaxed line-clamp-4" style={{ color: 'var(--text-secondary)' }}>
        {snippet(note.body) || 'No content'}
      </p>
    </button>
  );
}

export default function NotesList({ notes, selectedId, onSelect, onNew, view }) {
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
        <div className="flex-1 overflow-y-auto px-4 pb-4">
          <div className="grid grid-cols-2 gap-3">
            {notes.map(n => (
              <NoteCard key={n.id} note={n} onClick={() => onSelect(n.id)} />
            ))}
            {notes.length === 0 && (
              <p className="col-span-2 text-sm text-center py-12" style={{ color: 'var(--text-secondary)' }}>
                No notes yet. Create one!
              </p>
            )}
          </div>
        </div>
      </div>
    );
  }

  // Desktop: sidebar list
  return (
    <div
      className="flex flex-col h-full overflow-hidden border-r"
      style={{ borderColor: 'var(--border)', width: 260, flexShrink: 0 }}
    >
      <div
        className="flex items-center justify-between px-3 py-3 border-b"
        style={{ borderColor: 'var(--border)' }}
      >
        <span className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
          Notes
        </span>
        <NewButton onClick={onNew} />
      </div>
      <div className="flex-1 overflow-y-auto p-2 space-y-0.5">
        {notes.map(n => (
          <NoteRow
            key={n.id}
            note={n}
            active={n.id === selectedId}
            onClick={() => onSelect(n.id)}
          />
        ))}
        {notes.length === 0 && (
          <p className="text-xs text-center py-8" style={{ color: 'var(--text-secondary)' }}>
            No notes yet.
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
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M6 1v10M1 6h10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      </svg>
      New
    </button>
  );
}
