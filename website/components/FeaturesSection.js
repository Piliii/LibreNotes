import { LockKeyhole, WifiOff, Server, ShieldCheck } from 'lucide-react';

const FEATURES = [
  {
    Icon: LockKeyhole,
    title: "End-to-end encrypted",
    body: "Notes are encrypted on your device before they leave it. The server only ever stores ciphertext, so it can't read your content even if it gets compromised.",
  },
  {
    Icon: WifiOff,
    title: "Offline-first",
    body: "Every device keeps a full local copy. Notes open instantly and editing works with no internet. Changes sync automatically when your server is reachable.",
  },
  {
    Icon: Server,
    title: "Self-hosted",
    body: "Run the sync server on your home network - a Raspberry Pi, an old laptop, anything. Your data stays on hardware you own and never touches a third-party cloud.",
  },
  {
    Icon: ShieldCheck,
    title: "Free and open source",
    body: "Licensed AGPLv3. Read the code, audit it, self-host it, fork it. No paywalls, no telemetry, no lock-in. Available on F-Droid, AUR, and Flatpak.",
  },
];

export default function FeaturesSection() {
  return (
    <section id="features" className="px-4 py-24 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
      <div className="mx-auto max-w-5xl">
        <div className="mb-14 text-center">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
            Built for privacy, not profit
          </h2>
          <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
            Simple decisions: you own the data, you control the server, the code is public.
          </p>
        </div>

        <div className="grid gap-6 sm:grid-cols-2">
          {FEATURES.map(({ Icon, title, body }) => (
            <div
              key={title}
              className="group rounded-2xl border p-7 transition-all duration-200 hover:-translate-y-1 hover:border-[#ff6900]"
              style={{ background: 'var(--bg-surface)', borderColor: 'var(--border)' }}
            >
              <div
                className="mb-4 inline-flex rounded-xl p-2.5 transition-colors duration-200 group-hover:bg-[#ff6900]"
                style={{ background: 'var(--bg-elevated)', color: 'var(--accent)' }}
              >
                <Icon size={26} strokeWidth={1.6} className="transition-colors duration-200 group-hover:text-white" />
              </div>
              <h3 className="text-base font-semibold" style={{ color: 'var(--text-primary)' }}>
                {title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                {body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
