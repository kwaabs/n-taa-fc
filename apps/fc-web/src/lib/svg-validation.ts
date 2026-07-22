import DOMPurify from "dompurify";

export interface SvgValidation {
  valid: boolean;
  error?: string;
  sanitized?: string;
}

const MAX_SVG_BYTES = 50_000; // 50KB cap

/**
 * Validates + sanitizes an SVG string for safe use as a map marker.
 * - Confirms it's well-formed <svg>
 * - Strips scripts, event handlers, foreignObject, external refs
 * - Enforces a size cap
 */
export function validateAndSanitizeSvg(input: string): SvgValidation {
  const trimmed = (input || "").trim();

  if (!trimmed) {
    // Empty is valid (means "no custom SVG")
    return { valid: true, sanitized: "" };
  }

  if (trimmed.length > MAX_SVG_BYTES) {
    return { valid: false, error: `SVG too large (max ${MAX_SVG_BYTES / 1000}KB).` };
  }

  // Must open with <svg and close with </svg>
  if (!/^<svg[\s>]/i.test(trimmed) || !/<\/svg>\s*$/i.test(trimmed)) {
    return { valid: false, error: "Must be a complete <svg>…</svg> element." };
  }

  // Confirm well-formed XML
  const doc = new DOMParser().parseFromString(trimmed, "image/svg+xml");
  if (doc.querySelector("parsererror")) {
    return { valid: false, error: "Malformed SVG markup." };
  }
  if (doc.documentElement.nodeName.toLowerCase() !== "svg") {
    return { valid: false, error: "Root element must be <svg>." };
  }

  // Sanitize — SVG profile, strip dangerous tags/attrs
  const sanitized = DOMPurify.sanitize(trimmed, {
    USE_PROFILES: { svg: true, svgFilters: true },
    FORBID_TAGS: ["script", "foreignObject", "a"],
    FORBID_ATTR: [
      "onload", "onclick", "onmouseover", "onerror",
      "onmouseenter", "onmouseleave", "onfocus", "onblur",
    ],
  });

  if (!sanitized || !/<svg[\s>]/i.test(sanitized)) {
    return { valid: false, error: "No safe SVG content after sanitizing." };
  }

  return { valid: true, sanitized };
}