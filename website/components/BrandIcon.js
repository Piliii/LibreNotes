// Renders a simple-icons SVG given an icon object { path, title }
export default function BrandIcon({ icon, size = 20, className = '', style = {} }) {
  return (
    <svg
      role="img"
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="currentColor"
      aria-label={icon.title}
      className={className}
      style={style}
    >
      <path d={icon.path} />
    </svg>
  );
}
