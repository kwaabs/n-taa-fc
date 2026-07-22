import { useEffect, useState } from "react";
import { X, ChevronLeft, ChevronRight, Download, ExternalLink } from "lucide-react";

interface LightboxItem {
  kind: string;
  url: string;
  fieldId: string;
}

interface Props {
  items: LightboxItem[];
  startIndex?: number;
  onClose: () => void;
}

export function AttachmentLightbox({ items, startIndex = 0, onClose }: Props) {
  const [index, setIndex] = useState(startIndex);

  const current = items[index];

  const prev = () => setIndex((i) => (i > 0 ? i - 1 : items.length - 1));
  const next = () => setIndex((i) => (i < items.length - 1 ? i + 1 : 0));

  // Keyboard navigation
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft") prev();
      if (e.key === "ArrowRight") next();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!current) return null;

  return (
    <div className="fixed inset-0 z-[60] bg-black/90 flex flex-col">
      {/* Header */}
      <div
        className="flex items-center justify-between px-4 py-3 text-white shrink-0"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 min-w-0">
          <p className="text-sm font-medium truncate">
            {current.fieldId}
          </p>
          {items.length > 1 && (
            <span className="text-xs text-gray-400">
              {index + 1} / {items.length}
            </span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <a
            href={current.url}
            download
            className="flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-1.5 text-sm hover:bg-white/20"
            onClick={(e) => e.stopPropagation()}
          >
            <Download className="h-4 w-4" /> Download
          </a>
          <a
            href={current.url}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1.5 rounded-lg bg-white/10 px-3 py-1.5 text-sm hover:bg-white/20"
            onClick={(e) => e.stopPropagation()}
          >
            <ExternalLink className="h-4 w-4" /> Open in tab
          </a>
          <button
            onClick={onClose}
            className="rounded-lg bg-white/10 p-1.5 hover:bg-white/20"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
      </div>

      {/* Body */}
      <div
        className="flex-1 flex items-center justify-center relative px-4 pb-4"
        onClick={(e) => e.stopPropagation()}
      >
        {items.length > 1 && (
          <button
            onClick={(e) => { e.stopPropagation(); prev(); }}
            className="absolute left-4 z-10 rounded-full bg-white/10 p-2 hover:bg-white/20 text-white"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
        )}

        {(current.kind === "photo" || current.kind === "signature" || current.kind === "barcode_image") && (
          <img
            src={current.url}
            alt={current.fieldId}
            className="max-w-full max-h-full object-contain"
          />
        )}

        {current.kind === "video" && (
          <video
            src={current.url}
            controls
            autoPlay
            className="max-w-full max-h-full"
          />
        )}

        {items.length > 1 && (
          <button
            onClick={(e) => { e.stopPropagation(); next(); }}
            className="absolute right-4 z-10 rounded-full bg-white/10 p-2 hover:bg-white/20 text-white"
          >
            <ChevronRight className="h-6 w-6" />
          </button>
        )}
      </div>
    </div>
  );
}