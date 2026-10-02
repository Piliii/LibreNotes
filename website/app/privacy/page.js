import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export const metadata = {
  title: 'Privacy Policy - LibreNotes',
  description:
    'LibreNotes collects no data. No accounts, analytics, ads, or trackers. Notes stay on your devices and sync only to a server you run.',
};

const CONTACT_EMAIL = 'contact@ayopili.com';
const LAST_UPDATED = 'September 29, 2026';

function Section({ id, title, children }) {
  return (
    <section id={id} className="mt-12 scroll-mt-24">
      <h2 className="text-xl font-semibold tracking-tight" style={{ color: 'var(--text-primary)' }}>
        {title}
      </h2>
      <div className="mt-3 space-y-3 text-[15px] leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
        {children}
      </div>
    </section>
  );
}

function List({ children }) {
  return <ul className="list-disc space-y-1.5 pl-5">{children}</ul>;
}

function Strong({ children }) {
  return <strong style={{ color: 'var(--text-primary)' }}>{children}</strong>;
}

function A({ href, children }) {
  return (
    <a
      href={href}
      className="underline underline-offset-2 hover:text-[#ff6900]"
      style={{ color: 'var(--text-primary)' }}
    >
      {children}
    </a>
  );
}

export default function PrivacyPage() {
  return (
    <>
      <Navbar />
      <main className="px-4 pb-24 pt-32 sm:px-6 lg:px-8" style={{ background: 'var(--bg-base)' }}>
        <article className="mx-auto max-w-3xl">
          <header className="text-center">
            <h1 className="text-3xl font-bold tracking-tight sm:text-4xl" style={{ color: 'var(--text-primary)' }}>
              Privacy Policy
            </h1>
            <p className="mt-3 text-base" style={{ color: 'var(--text-secondary)' }}>
              LibreNotes, Android package <code>dev.librenotes.app</code>. Last updated {LAST_UPDATED}.
            </p>
          </header>

          <div
            className="mt-10 rounded-xl border p-5 text-[15px] leading-relaxed"
            style={{ borderColor: '#ff6900', background: '#1f1408', color: 'var(--text-secondary)' }}
          >
            <p className="font-semibold" style={{ color: '#ff6900' }}>
              The short version
            </p>
            <p className="mt-2">
              LibreNotes does not collect your data. There are no accounts, no analytics, no ads, and no
              trackers, and the developer never receives your notes or anything about how you use the app. Your
              notes live on your own devices and, if you choose to turn sync on, on a server that you run
              yourself.
            </p>
          </div>

          <Section id="who" title="Who this covers">
            <p>
              LibreNotes is a free, open-source (AGPLv3) note-taking app for Android, Linux, and the web,
              developed by an individual developer. This policy covers the LibreNotes apps and the project
              website at <A href="https://librenotes.ayopili.com">librenotes.ayopili.com</A>. The complete
              source code is public at{' '}
              <A href="https://github.com/Piliii/LibreNotes">github.com/Piliii/LibreNotes</A>, so every claim
              here can be checked against the code.
            </p>
          </Section>

          <Section id="collect" title="What the developer collects">
            <p>
              <Strong>Nothing.</Strong> The app has no developer-operated backend. It does not contact any
              server operated by the developer, and it contains no analytics, crash-reporting, advertising, or
              tracking code. It does not use Google Play Services or Firebase.
            </p>
          </Section>

          <Section id="device" title="What is stored on your device">
            <List>
              <li>
                <Strong>Your notes.</Strong> The title and body of each note are encrypted before being written
                to the app&apos;s local database, using a key that is kept in your system&apos;s secure storage
                (the platform keyring). Other note properties, such as color, pinned/archived state, and
                timestamps, are stored in the app&apos;s private database on your device.
              </li>
              <li>
                <Strong>Sync settings</Strong> (only if you turn sync on): the address of your server, an access
                token for it, and the encrypted key material needed to unlock your notes on a new device.
              </li>
              <li>
                <Strong>Files you pick.</Strong> If you import or export notes as Markdown files, the app reads
                or writes only the files and folder you choose in the system file picker.
              </li>
            </List>
            <p>
              All of this stays in the app&apos;s private storage on your device. Uninstalling the app or
              clearing its data removes it.
            </p>
          </Section>

          <Section id="sync" title="Sync (optional) and your server">
            <p>
              Sync is off until you connect the app to a LibreNotes server of your choosing. That might be one
              you host yourself, for example on your home network, or one run by someone else you trust, such as a
              family member or friend. The developer does not run or have access to any server on your behalf.
            </p>
            <p>Notes are encrypted on your device before they are sent. The server only ever stores:</p>
            <List>
              <li>the encrypted note contents (ciphertext) and its per-write nonce;</li>
              <li>
                sync bookkeeping: a random note ID, a revision number, a change counter, deleted/purged flags, and a
                last-modified time;
              </li>
              <li>
                your wrapped (passphrase-encrypted) key and its salt and key-derivation settings, which the
                server cannot open.
              </li>
            </List>
            <p>
              The server never has your passphrase or your encryption key, so it cannot read your notes. Whoever
              runs the server can see the bookkeeping above and roughly how large each encrypted note is, and can
              see the network address that connects to it.
            </p>
            <p>
              <Strong>Transport security is up to you.</Strong> The app connects to whatever address you enter.
              If you use a plain <code>http://</code> address, for example on a home network, the connection
              itself is not encrypted, although note contents remain end-to-end encrypted either way. For
              access from outside your home network, use a private network such as WireGuard or Tailscale, or put
              the server behind HTTPS.
            </p>
          </Section>

          <Section id="permissions" title="Permissions the Android app uses">
            <p>
              The Android app requests one permission: <Strong>Internet</Strong>, used only to talk to the sync
              server you configure. It does not request access to your location, contacts, camera, microphone,
              photos, or shared storage.
            </p>
          </Section>

          <Section id="third-parties" title="Third parties">
            <List>
              <li>
                <Strong>In the app:</Strong> none. The app does not embed third-party SDKs that collect data.
              </li>
              <li>
                <Strong>Links in your notes:</Strong> tapping a link opens it in your browser or another app.
                That site&apos;s own privacy policy applies from then on.
              </li>
              <li>
                <Strong>Where you install it from:</Strong> Google Play, F-Droid, GitHub, and package
                repositories operate under their own policies and may keep their own download or installation
                records. The app cannot see or control those, and does not send anything to them.
              </li>
            </List>
          </Section>

          <Section id="website" title="This website">
            <List>
              <li>The website&apos;s own code sets no cookies and runs no analytics or advertising scripts.</li>
              <li>
                Its text font is loaded from a third-party font service, Bunny Fonts (fonts.bunny.net), so your
                browser makes a request to that service, which can see your IP address, when you view the site.
              </li>
              <li>
                The site is hosted on Vercel and protected by Cloudflare. Those services may set their own
                technical cookies and keep ordinary server logs (such as IP address and requested page) for
                security and operations, under their own privacy policies.
              </li>
              <li>
                The live demo saves its sample notes in your browser&apos;s local storage only. They are never
                sent anywhere. The &quot;what&apos;s new&quot; notice also remembers the last version you saw in
                local storage. Clearing your browser data removes both.
              </li>
            </List>
          </Section>

          <Section id="children" title="Children">
            <p>
              LibreNotes is a general-purpose notes app and is not directed at children. Because it collects no
              personal data from anyone, it collects none from children either.
            </p>
          </Section>

          <Section id="control" title="Your control over your data">
            <p>
              Your notes are yours. You can export them as Markdown files at any time, delete them in the app,
              and remove everything by uninstalling. Data on a sync server is controlled by whoever runs that
              server, which is you if you set it up. Since the developer holds no data about you, there is
              nothing for the developer to access, correct, or delete on your behalf.
            </p>
          </Section>

          <Section id="changes" title="Changes to this policy">
            <p>
              If the app&apos;s data practices ever change, this page will be updated and the date at the top
              revised. The full history is visible in the project&apos;s public repository.
            </p>
          </Section>

          <Section id="contact" title="Contact">
            <p>
              Questions about this policy: <A href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</A>. For security
              issues, please use{' '}
              <A href="https://github.com/Piliii/LibreNotes/security/advisories/new">GitHub private security advisories</A>.
            </p>
          </Section>
        </article>
      </main>
      <Footer />
    </>
  );
}
