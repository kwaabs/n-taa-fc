import {
    ImageIcon, Music, Video, FileSignature, QrCode, FileText, Loader,
  } from "lucide-react";
  
  interface Props {
    attachment: any;
    downloadUrl?: string;
    inline?: boolean;
    onClick?: () => void;
  }
  
  const kindIcons: Record<string, any> = {
    photo: ImageIcon,
    audio: Music,
    video: Video,
    signature: FileSignature,
    barcode_image: QrCode,
    file: FileText,
  };
  
  export function AttachmentThumbnail({ attachment, downloadUrl, inline, onClick }: Props) {
    const att = attachment;
    const Icon = kindIcons[att.kind] || FileText;
    const isPending = att.status !== "uploaded";
  
    // Audio is rendered inline (per design)
    if (inline && att.kind === "audio" && downloadUrl) {
      return (
        <div className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2">
          <Music className="h-4 w-4 text-purple-600 shrink-0" />
          <audio controls src={downloadUrl} className="h-7 flex-1 min-w-0" />
        </div>
      );
    }
  
    // Images get a thumbnail tile
    if ((att.kind === "photo" || att.kind === "signature" || att.kind === "barcode_image") && downloadUrl) {
      return (
        <button
          onClick={onClick}
          className="relative rounded-lg overflow-hidden border border-gray-200 bg-gray-50 hover:border-blue-400 transition-colors"
          style={{ width: 80, height: 80 }}
          title={att.field_id}
        >
          <img
            src={downloadUrl}
            alt={att.field_id}
            className="w-full h-full object-cover"
          />
        </button>
      );
    }
  
    // Video — thumbnail-style with play overlay
    if (att.kind === "video" && downloadUrl) {
      return (
        <button
          onClick={onClick}
          className="relative rounded-lg overflow-hidden border border-gray-200 bg-gray-900 hover:border-blue-400 transition-colors flex items-center justify-center"
          style={{ width: 80, height: 80 }}
          title={att.field_id}
        >
          <Video className="h-8 w-8 text-white" />
          <span className="absolute bottom-1 right-1 rounded bg-black/70 px-1 py-0.5 text-[10px] text-white">
            ▶
          </span>
        </button>
      );
    }
  
    // Pending or generic file
    return (
      <button
        onClick={onClick}
        disabled={isPending}
        className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-xs transition-colors ${
          isPending
            ? "border-yellow-200 bg-yellow-50 text-yellow-700 cursor-default"
            : "border-gray-200 bg-white text-gray-700 hover:border-blue-300 hover:bg-blue-50"
        }`}
        title={att.field_id}
      >
        {isPending ? (
          <Loader className="h-4 w-4 animate-spin" />
        ) : (
          <Icon className="h-4 w-4 text-gray-500" />
        )}
        <span className="truncate max-w-[140px]">
          {att.mime_type || att.kind}
        </span>
        {att.size_bytes > 0 && !isPending && (
          <span className="text-gray-400">
            {formatBytes(att.size_bytes)}
          </span>
        )}
      </button>
    );
  }
  
  function formatBytes(n: number): string {
    if (n < 1024) return n + " B";
    if (n < 1024 * 1024) return Math.round(n / 1024) + " KB";
    return (n / 1024 / 1024).toFixed(1) + " MB";
  }