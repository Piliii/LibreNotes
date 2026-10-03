'use client';

import { useEffect, useRef, useState } from 'react';
import { X, ZoomIn, ZoomOut } from 'lucide-react';

const SCREENSHOTS = [
  { src: '/screenshots/1.jpg', label: 'Notes list', alt: 'LibreNotes on Android: a two-column grid of note cards' },
  { src: '/screenshots/2.jpg', label: 'Note editor', alt: 'LibreNotes on Android: the note editor with a markdown note open' },
  { src: '/screenshots/3.jpg', label: 'Sync settings', alt: 'LibreNotes on Android: the sync settings page' },
];

const MIN_ZOOM = 1;
const MAX_ZOOM = 4;

function Phone({ src, label, alt, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex flex-col items-center gap-3 shrink-0 group cursor-zoom-in"
    >
      <div
        className="overflow-hidden rounded-[2.1rem] border-[5px] transition-transform duration-300 group-hover:scale-[1.03]"
        style={{
          borderColor: '#2e2e2e',
          boxShadow: '0 24px 60px rgba(0,0,0,0.6)',
          width: 200,
        }}
      >
        <img
          src={src}
          alt={alt}
          style={{ display: 'block', width: '100%' }}
        />
      </div>
      <span
        className="text-xs font-medium transition-colors duration-200 group-hover:text-[#ff6900]"
        style={{ color: 'var(--text-secondary)' }}
      >
        {label}
      </span>
    </button>
  );
}

function ImageViewerModal({ screenshot, onClose }) {
  const [zoom, setZoom] = useState(1);
  const [isPanning, setIsPanning] = useState(false);
  const containerRef = useRef(null);
  const panStartRef = useRef({ x: 0, y: 0, scrollLeft: 0, scrollTop: 0 });

  useEffect(() => {
    setZoom(1);
  }, [screenshot]);

  useEffect(() => {
    const onKeyDown = e => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [onClose]);

  const zoomIn = () => setZoom(z => Math.min(MAX_ZOOM, +(z + 0.5).toFixed(2)));
  const zoomOut = () => setZoom(z => Math.max(MIN_ZOOM, +(z - 0.5).toFixed(2)));

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    // Native listener (not React's onWheel) so preventDefault actually
    // stops the browser from also scrolling the overflow-auto container.
    const onWheel = e => {
      e.preventDefault();
      setZoom(z => {
        const next = z - e.deltaY * 0.0015;
        return Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, +next.toFixed(2)));
      });
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [screenshot]);

  // Left-click-and-drag panning, like a normal image viewer.
  useEffect(() => {
    if (!isPanning) return;
    const onMouseMove = e => {
      const el = containerRef.current;
      if (!el) return;
      el.scrollLeft = panStartRef.current.scrollLeft - (e.clientX - panStartRef.current.x);
      el.scrollTop = panStartRef.current.scrollTop - (e.clientY - panStartRef.current.y);
    };
    const onMouseUp = () => setIsPanning(false);
    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);
    return () => {
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };
  }, [isPanning]);

  const onImageMouseDown = e => {
    if (e.button !== 0) return;
    e.preventDefault(); // stop native image-ghost drag / text selection
    e.stopPropagation();
    const el = containerRef.current;
    if (!el) return;
    panStartRef.current = { x: e.clientX, y: e.clientY, scrollLeft: el.scrollLeft, scrollTop: el.scrollTop };
    setIsPanning(true);
  };

  if (!screenshot) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={screenshot.label}
      className="fixed inset-0 z-50 flex items-center justify-center p-6"
      style={{ background: 'rgba(0,0,0,0.85)' }}
      onClick={onClose}
    >
      {/* Close button */}
      <button
        type="button"
        onClick={onClose}
        aria-label="Close image viewer"
        className="absolute top-5 right-5 rounded-full p-2 text-white/80 transition-colors duration-200 hover:text-[#ff6900]"
        style={{ background: 'rgba(255,255,255,0.08)' }}
      >
        <X size={22} />
      </button>

      {/* Zoom controls */}
      <div
        className="absolute bottom-6 left-1/2 -translate-x-1/2 flex items-center gap-2 rounded-full px-3 py-2"
        style={{ background: 'rgba(255,255,255,0.08)' }}
        onClick={e => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={zoomOut}
          disabled={zoom <= MIN_ZOOM}
          aria-label="Zoom out"
          className="rounded-full p-2 text-white/80 transition-colors duration-200 hover:text-[#ff6900] disabled:opacity-30 disabled:hover:text-white/80"
        >
          <ZoomOut size={18} />
        </button>
        <span className="min-w-[3.5rem] text-center text-xs font-medium text-white/80">
          {Math.round(zoom * 100)}%
        </span>
        <button
          type="button"
          onClick={zoomIn}
          disabled={zoom >= MAX_ZOOM}
          aria-label="Zoom in"
          className="rounded-full p-2 text-white/80 transition-colors duration-200 hover:text-[#ff6900] disabled:opacity-30 disabled:hover:text-white/80"
        >
          <ZoomIn size={18} />
        </button>
      </div>

      <div
        ref={containerRef}
        onClick={e => e.stopPropagation()}
        className="overflow-auto rounded-[1.5rem] border-[5px]"
        style={{
          borderColor: '#2e2e2e',
          boxShadow: '0 24px 60px rgba(0,0,0,0.6)',
          maxWidth: '90vw',
          maxHeight: '85vh',
        }}
      >
        <img
          src={screenshot.src}
          alt={screenshot.alt}
          draggable={false}
          onClick={e => e.stopPropagation()}
          onMouseDown={onImageMouseDown}
          onDoubleClick={e => {
            e.stopPropagation();
            setZoom(z => (z > MIN_ZOOM ? MIN_ZOOM : 2));
          }}
          style={{
            display: 'block',
            width: 320 * zoom,
            maxWidth: 'none',
            userSelect: 'none',
            transition: isPanning ? 'none' : 'width 150ms ease-out',
            cursor: isPanning ? 'grabbing' : zoom > MIN_ZOOM ? 'grab' : 'zoom-in',
          }}
        />
      </div>
    </div>
  );
}

export default function ScreenshotsSection() {
  const [selected, setSelected] = useState(null);

  return (
    <section id="screenshots" className="py-20" style={{ background: 'var(--bg-surface)' }}>
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
        <div className="mb-12 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Clean, fast, private
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Works on Android and Linux. No account needed to get started.
          </p>
        </div>
      </div>

      {/* Scroll container - full bleed so padding doesn't clip the overflow */}
      <div className="overflow-x-auto pb-4">
        <div className="flex gap-8 sm:gap-12 px-8 sm:justify-center sm:px-0" style={{ width: 'max-content', margin: '0 auto' }}>
          {SCREENSHOTS.map(s => (
            <Phone key={s.src} {...s} onClick={() => setSelected(s)} />
          ))}
        </div>
      </div>

      <ImageViewerModal screenshot={selected} onClose={() => setSelected(null)} />
    </section>
  );
}
