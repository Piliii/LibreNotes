// Resolves /dl/<kind> to the matching asset of the latest GitHub release, so
// download buttons can link straight to a file even though asset names carry
// the version (LibreNotes-1.5.7-amd64.deb). Wired up by rewrites in vercel.json.
// Falls back to the releases page if GitHub is unreachable or nothing matches.

const REPO = 'Piliii/LibreNotes';
const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;

const PATTERNS = {
  deb: /^LibreNotes-.+-amd64\.deb$/,
  rpm: /^LibreNotes-.+-x86_64\.rpm$/,
  appimage: /^LibreNotes-.+\.AppImage$/,
  tarball: /^LibreNotes-.+-linux-x86_64\.tar\.gz$/,
  apk: /^LibreNotes-.+-android-arm64\.apk$/,
};

module.exports = async function handler(req, res) {
  const pattern = PATTERNS[req.query.kind];
  if (!pattern) {
    res.status(404).send('Unknown download');
    return;
  }

  let target = RELEASES_PAGE;
  try {
    const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'librenotes-website' };
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    const r = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers });
    if (r.ok) {
      const release = await r.json();
      const asset = (release.assets || []).find(a => pattern.test(a.name));
      if (asset) target = asset.browser_download_url;
    }
  } catch {
    // fall through to the releases page
  }

  // Cache the lookup at the edge so GitHub's unauthenticated rate limit
  // (60/h per IP) isn't hit; a new release shows up within minutes.
  const found = target !== RELEASES_PAGE;
  res.setHeader('Cache-Control', found ? 's-maxage=300, stale-while-revalidate=3600' : 's-maxage=30');
  res.redirect(302, target);
};
