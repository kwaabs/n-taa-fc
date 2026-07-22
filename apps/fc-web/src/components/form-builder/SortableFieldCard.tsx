import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import {
  GripVertical, X, Type, Hash, ToggleLeft, ListChecks, Calendar, Clock,
  MapPin, Camera, Mic, StickyNote, FolderOpen, Repeat, Calculator, Route,
  Pentagon, QrCode
} from "lucide-react";

const typeIcons: Record<string, any> = {
  text: Type, integer: Hash, decimal: Hash, select_one: ToggleLeft,
  select_multiple: ListChecks, date: Calendar, datetime: Calendar, time: Clock,
  geopoint: MapPin, geotrace: Route, geoshape: Pentagon, photo: Camera,
  audio: Mic, barcode: QrCode, note: StickyNote, group: FolderOpen,
  repeat: Repeat, calculation: Calculator,
};

interface Props {
  field: any;
  isSelected: boolean;
  onSelect: () => void;
  onDelete: () => void;
}

export function SortableFieldCard({ field, isSelected, onSelect, onDelete }: Props) {
  const {
    attributes, listeners, setNodeRef, transform, transition, isDragging,
  } = useSortable({ id: field.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  const Icon = typeIcons[field.type] || Type;

  return (
    <div
      ref={setNodeRef}
      style={style}
      onClick={onSelect}
      className={`flex items-center gap-3 rounded-lg border px-3 py-3 cursor-pointer transition-colors ${
        isDragging ? "opacity-50" : ""
      } ${
        isSelected
          ? "border-blue-500 bg-blue-50 ring-1 ring-blue-500"
          : "border-gray-200 bg-white hover:border-gray-300"
      }`}
    >
      <div {...attributes} {...listeners} className="cursor-grab text-gray-400 hover:text-gray-600">
        <GripVertical className="h-4 w-4" />
      </div>
      <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs font-mono text-gray-500">
        {field.type}
      </span>
      <span className="flex-1 text-sm font-medium text-gray-900 truncate">
        {field.label?.en || field.id}
      </span>
      {field.required && <span className="text-xs text-red-500">*</span>}
      <button
        onClick={(e) => { e.stopPropagation(); onDelete(); }}
        className="text-gray-400 hover:text-red-500 transition-colors"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}