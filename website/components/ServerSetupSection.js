const GH_RELEASE = 'https://github.com/Piliii/LibreNotes/releases/latest';

const STEPS = [
  {
    n: '1',
    title: 'Download the server binary',
    body: 'One self-contained executable, no runtime or dependencies required. Replace linux-x64 with linux-arm64 if on a Raspberry Pi.',
    code: `curl -Lo librenotes-server \\
  https://librenotes.ayopili.com/dl/server
chmod +x librenotes-server`,
  },
  {
    n: '2',
    title: 'Run it',
    body: 'On startup it prints an auth token and the address it listens on. Copy the token - you will need it in the app.',
    code: `./librenotes-server
# Token: aBc123...   <-- copy this
# Listening on 0.0.0.0:7070`,
  },
  {
    n: '3',
    title: 'Connect the app',
    body: 'Open Settings then Sync in the app. Enter your server IP and the token. Use the same passphrase on every device.',
    code: `Server URL:  http://<server-ip>:7070
Token:       aBc123...
Passphrase:  (pick something strong)`,
  },
];

export default function ServerSetupSection() {
  return (
    <section id="server" className="px-4 py-24 sm:px-6 lg:px-8" style={{ background: 'var(--bg-surface)' }}>
      <div className="mx-auto max-w-5xl">
        <div className="mb-14 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Set up the sync server
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Runs on any Linux machine on your home network. Takes about 5 minutes.
          </p>
        </div>

        <div className="grid gap-6 lg:grid-cols-3">
          {STEPS.map(({ n, title, body, code, cta }) => (
            <div
              key={n}
              className="group flex min-w-0 flex-col gap-4 rounded-2xl border p-6 transition-all duration-200 hover:border-[#ff6900] hover:-translate-y-1"
              style={{ background: 'var(--bg-elevated)', borderColor: 'var(--border)' }}
            >
              <div className="flex items-center gap-3">
                <span
                  className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold transition-colors duration-200 group-hover:bg-white group-hover:text-[#ff6900]"
                  style={{ background: 'var(--accent)', color: '#fff' }}
                >
                  {n}
                </span>
                <h3 className="text-sm font-semibold" style={{ color: 'var(--text-primary)' }}>
                  {title}
                </h3>
              </div>

              <p className="text-xs leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                {body}
              </p>

              {cta && (
                <a
                  href={cta.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-semibold transition-colors duration-200 hover:bg-[#e55e00]"
                  style={{ background: 'var(--accent)', color: '#fff' }}
                >
                  {cta.label}
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                    <path d="M2 5h6M5 2l3 3-3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </a>
              )}

              <pre
                className="mt-auto min-w-0 overflow-x-auto rounded-lg p-3 text-[11px] leading-relaxed"
                style={{ background: '#111', color: '#a0a0a0', fontFamily: 'monospace', whiteSpace: 'pre', wordBreak: 'normal' }}
              >
                {code}
              </pre>
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
              Put your devices and server on a Tailscale or WireGuard mesh. No server changes needed - just update the URL in the app.
            </p>
          </div>
          <a
            href="https://github.com/Piliii/LibreNotes#readme"
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 rounded-lg border px-4 py-2 text-xs font-semibold transition-colors duration-200 hover:border-[#ff6900] hover:text-[#ff6900]"
            style={{ borderColor: 'var(--border)', color: 'var(--text-secondary)' }}
          >
            Full README
          </a>
        </div>
      </div>
    </section>
  );
}
