export function snippet(body) {
  const plain = body.replace(/[#*`~_\[\]>]/g, '').replace(/\n+/g, ' ').trim();
  return plain.length > 120 ? plain.slice(0, 120) + '…' : plain;
}

export function timeAgo(ts) {
  const diff = Date.now() - ts;
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}
