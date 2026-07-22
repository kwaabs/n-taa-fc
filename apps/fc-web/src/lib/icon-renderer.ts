import * as Icons from "lucide-react";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

const cache = new Map<string, string>();

// Convert "water-drop" -> "WaterDrop" (PascalCase lookup)
function toPascalCase(name: string): string {
  return name
    .split("-")
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
    .join("");
}

export function iconToDataUrl(name: string, color = "#ffffff"): string | null {
  const key = `${name}|${color}`;
  if (cache.has(key)) return cache.get(key)!;

  const componentName = toPascalCase(name);
  const IconComponent = (Icons as any)[componentName];
  if (!IconComponent) return null;

  try {
    const svg = renderToStaticMarkup(
      createElement(IconComponent, {
        color,
        size: 24,
        strokeWidth: 2.5,
      })
    );
    const dataUrl = `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
    cache.set(key, dataUrl);
    return dataUrl;
  } catch {
    return null;
  }
}