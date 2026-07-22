import { useEffect, useState } from "react";
import { X, ChevronLeft, ChevronRight, Download, ExternalLink } from "lucide-react";

export interface LightboxItem {
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

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft") prev();
      if (e.key === "ArrowRight") next();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [onClose]);

  if (!current) return null;

  const isImage =
    current.kind === "photo" ||
    current.kind === "signature" ||
    current.kind === "barcode_image" ||
    current.kind === "image";

  return (
    <div className="fixed inset-0 z-[80] flex flex-col bg-black/90">
      <div
        className="flex shrink-0 items-center justify-between px-4 py-3 text-white"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex min-w-0 items-center gap-3">
          <p className="truncate text-sm font-medium">{current.fieldId}</p>
          {items.length > 1 && (
            <span className="text-xs text-white/50">
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
            type="button"
            onClick={onClose}
            className="rounded-lg bg-white/10 p-1.5 hover:bg-white/20"
            aria-label="Close"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
      </div>

      <div
        className="relative flex flex-1 items-center justify-center px-4 pb-4"
        onClick={(e) => e.stopPropagation()}
      >
        {items.length > 1 && (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              prev();
            }}
            className="absolute left-4 z-10 rounded-full bg-white/10 p-2 text-white hover:bg-white/20"
            aria-label="Previous"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
        )}

        {isImage && (
          <img
            src={current.url}
            alt={current.fieldId}
            className="max-h-full max-w-full object-contain"
          />
        )}

        {current.kind === "video" && (
          <video
            src={current.url}
            controls
            autoPlay
            className="max-h-full max-w-full"
          />
        )}

        {!isImage && current.kind !== "video" && (
          <a
            href={current.url}
            target="_blank"
            rel="noreferrer"
            className="rounded-lg bg-white/10 px-4 py-2 text-sm text-white hover:bg-white/20"
          >
            Open file
          </a>
        )}

        {items.length > 1 && (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              next();
            }}
            className="absolute right-4 z-10 rounded-full bg-white/10 p-2 text-white hover:bg-white/20"
            aria-label="Next"
          >
            <ChevronRight className="h-6 w-6" />
          </button>
        )}
      </div>
    </div>
  );
}
