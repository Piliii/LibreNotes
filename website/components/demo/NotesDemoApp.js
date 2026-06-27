'use client';

import { useState, useEffect } from 'react';
import { useNotes } from './useNotes';
import NotesList from './NotesList';
import NoteEditor from './NoteEditor';

function useIsMobile() {
  const [mobile, setMobile] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 767px)');
    setMobile(mq.matches);
    const handler = e => setMobile(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);
  return mobile;
}

export default function NotesDemoApp() {
  const { notes, hydrated, createNote, updateNote, deleteNote } = useNotes();
  const isMobile = useIsMobile();
  const [selectedId, setSelectedId] = useState(null);
  // On mobile: 'list' or 'editor' view
  const [mobileView, setMobileView] = useState('list');

  // Auto-select first note once hydrated
  useEffect(() => {
    if (hydrated && selectedId === null && notes.length > 0) {
      setSelectedId(notes[0].id);
    }
  }, [hydrated, notes.length]);

  function handleNew() {
    const id = createNote();
    setSelectedId(id);
    if (isMobile) setMobileView('editor');
  }

  function handleSelect(id) {
    setSelectedId(id);
    if (isMobile) setMobileView('editor');
  }

  function handleDelete(id) {
    const nextId = deleteNote(id);
    setSelectedId(nextId);
    if (isMobile) setMobileView('list');
  }

  const selectedNote = notes.find(n => n.id === selectedId) ?? null;

  if (!hydrated) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="h-5 w-5 rounded-full border-2 border-t-transparent animate-spin" style={{ borderColor: 'var(--accent)' }} />
      </div>
    );
  }

  if (isMobile) {
    return (
      <div className="flex flex-col h-full overflow-hidden">
        {mobileView === 'list' ? (
          <NotesList
            notes={notes}
            selectedId={selectedId}
            onSelect={handleSelect}
            onNew={handleNew}
            view="grid"
          />
        ) : (
          <NoteEditor
            note={selectedNote}
            onUpdate={updateNote}
            onDelete={handleDelete}
            onBack={() => setMobileView('list')}
          />
        )}
      </div>
    );
  }

  // Desktop: sidebar + editor
  return (
    <div className="flex h-full overflow-hidden">
      <NotesList
        notes={notes}
        selectedId={selectedId}
        onSelect={handleSelect}
        onNew={handleNew}
        view="list"
      />
      <NoteEditor
        note={selectedNote}
        onUpdate={updateNote}
        onDelete={handleDelete}
      />
    </div>
  );
}
