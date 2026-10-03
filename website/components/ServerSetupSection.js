'use client';

import { useState, useCallback } from 'react';
import { Copy, Check } from 'lucide-react';

function CopyButton({ text }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (_) {}
  }, [text]);

  return (
    <button
      onClick={handleCopy}
      title="Copy to clipboard"
      aria-label={copied ? 'Copied' : 'Copy to clipboard'}
      className="absolute top-2 right-2 flex items-center justify-center rounded p-1.5 transition-all duration-300 cursor-pointer hover:rounded-[13px]"
      style={{
        background: copied ? '#1a3a1a' : '#1a1a1a',
        color: copied ? '#4ade80' : '#8a8a8a',
        border: '1px solid',
        borderColor: copied ? '#4ade80' : '#2a2a2a',
      }}
    >
      {copied ? <Check size={11} /> : <Copy size={11} />}
    </button>
  );
}

const BINARY_STEPS = [
  {
    n: '1',
    title: 'Download the server',
    body: 'A self-contained tarball with the binary, a systemd service file, and an installer - no runtime or dependencies to install yourself. On a Raspberry Pi, use /dl/server-arm64 instead of /dl/server below.',
    code: `curl -L https://librenotes.ayopili.com/dl/server | tar -xzf -
cd librenotes-server`,
  },
  {
    n: '2',
    title: 'Install it',
    body: 'Sets up a systemd service running as its own unprivileged user, and prints the auth token once it starts.',
    code: `sudo bash install.sh
# Token also readable any time at:
sudo cat /var/lib/librenotes/token`,
  },
  {
    n: '3',
    title: 'Connect the app',
    body: 'Open Settings → Sync in the app. Enter your server IP and the token. Use the same passphrase on every device.',
    code: `Server URL:  http://<server-ip>:8787
Token:       aBc123...
Passphrase:  (pick something strong)`,
  },
];

const DOCKER_STEPS = [
  {
    n: '1',
    title: 'Download the compose file',
    body: 'Fetches a ready-to-use compose file. Data is stored in a named volume so it survives container updates.',
    code: `curl -Lo docker-compose.yml https://librenotes.ayopili.com/dl/docker-compose`,
  },
  {
    n: '2',
    title: 'Start it',
    body: 'Docker pulls the image automatically. The auth token is printed on first run and persisted in the volume - check the logs to copy it.',
    code: `docker compose up -d
docker compose logs`,
  },
  {
    n: '3',
    title: 'Connect the app',
    body: 'Open Settings → Sync in the app. Enter your server IP and the token. Use the same passphrase on every device.',
    code: `Server URL:  http://<server-ip>:8787
Token:       aBc123...
Passphrase:  (pick something strong)`,
  },
];

export default function ServerSetupSection() {
  const [method, setMethod] = useState('binary');
  const steps = method === 'docker' ? DOCKER_STEPS : BINARY_STEPS;

  return (
    <section id="server" className="px-4 py-24 sm:px-6 lg:px-8" style={{ background: 'var(--bg-surface)' }}>
      <div className="mx-auto max-w-5xl">
        <div className="mb-10 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Set up the sync server
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Runs on any Linux machine on your home network. Takes about 5 minutes.
          </p>
        </div>

        {/* Method tabs */}
        <div className="mb-8 flex justify-center">
          <div
            role="tablist"
            aria-label="Install method"
            className="inline-flex rounded-xl p-1 gap-1"
            style={{ background: 'var(--bg-elevated)', border: '1px solid var(--border)' }}
          >
            {[
              { id: 'binary', label: 'Binary install' },
              { id: 'docker', label: 'Docker' },
            ].map(({ id, label }) => (
              <button
                key={id}
                type="button"
                role="tab"
                aria-selected={method === id}
                onClick={() => setMethod(id)}
                className={`rounded-lg px-5 py-2 text-sm font-semibold transition-all duration-300 cursor-pointer hover:rounded-[18px] ${
                  method !== id ? 'hover:bg-white/5' : ''
                }`}
                style={
                  method === id
                    ? { background: 'var(--accent)', color: '#fff' }
                    : { color: 'var(--text-secondary)' }
                }
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-col gap-6">
          {steps.map(({ n, title, body, code }) => (
            <div
              key={n}
              className="group flex flex-col gap-6 rounded-2xl border p-8 transition-colors duration-200 hover:border-[#ff6900] sm:flex-row sm:items-start"
              style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
            >
              <div className="flex min-w-0 flex-1 flex-col gap-3">
                <div className="flex items-center gap-3">
                  <span
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-bold transition-colors duration-200 group-hover:bg-white group-hover:text-[#ff6900]"
                    style={{ background: 'var(--accent)', color: '#fff' }}
                  >
                    {n}
                  </span>
                  <h3 className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>
                    {title}
                  </h3>
                </div>

                <p className="text-sm leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                  {body}
                </p>
              </div>

              <div className="relative min-w-0 flex-1">
                <pre
                  className="min-w-0 overflow-x-auto rounded-lg p-4 pr-10 text-xs leading-relaxed"
                  style={{ background: '#111', color: '#a0a0a0', fontFamily: 'monospace', whiteSpace: 'pre', wordBreak: 'normal' }}
                >
                  {code}
                </pre>
                <CopyButton text={code} />
              </div>
            </div>
          ))}
        </div>

        <div
          className="mt-8 flex flex-col gap-3 rounded-xl border p-5 transition-colors duration-200 hover:border-[#ff6900] sm:flex-row sm:items-center sm:justify-between"
          style={{ borderColor: 'var(--border)', background: 'var(--bg-elevated)' }}
        >
          <div>
            <p className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
              Want sync away from home too?
            </p>
            <p className="mt-0.5 text-xs" style={{ color: 'var(--text-secondary)' }}>
              Put your devices and server on a Tailscale or WireGuard mesh. No server changes needed - just update the URL in the app. To add HTTPS, put a Caddy, nginx or Tailscale proxy in front.
            </p>
          </div>
          <a
            href="https://github.com/Piliii/LibreNotes#readme"
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 rounded-lg border px-4 py-2 text-xs font-semibold transition-all duration-300 hover:rounded-[17px] hover:border-[#ff6900] hover:text-[#ff6900]"
            style={{ borderColor: 'var(--border)', color: 'var(--text-secondary)' }}
          >
            Full README
          </a>
        </div>
      </div>
    </section>
  );
}
