import { useDraggable } from "@dnd-kit/core";
import {
  Type, Hash, ToggleLeft, ListChecks, Calendar, Clock, MapPin, Route,
  Pentagon, Camera, Mic, QrCode, StickyNote, FolderOpen, Repeat, Calculator
} from "lucide-react";

const fieldTypes = [
  { category: "Input", items: [
    { type: "text", label: "Text", icon: Type },
    { type: "integer", label: "Number", icon: Hash },
    { type: "decimal", label: "Decimal", icon: Hash },
  ]},
  { category: "Choice", items: [
    { type: "select_one", label: "Select One", icon: ToggleLeft },
    { type: "select_multiple", label: "Select Multiple", icon: ListChecks },
  ]},
  { category: "Date / Time", items: [
    { type: "date", label: "Date", icon: Calendar },
    { type: "datetime", label: "Date & Time", icon: Calendar },
    { type: "time", label: "Time", icon: Clock },
  ]},
  { category: "Location", items: [
    { type: "geopoint", label: "GPS Point", icon: MapPin },
    { type: "geotrace", label: "GPS Trace", icon: Route },
    { type: "geoshape", label: "GPS Shape", icon: Pentagon },
  ]},
  { category: "Media", items: [
    { type: "photo", label: "Photo", icon: Camera },
    { type: "audio", label: "Audio", icon: Mic },
    { type: "barcode", label: "Barcode", icon: QrCode },
  ]},
  { category: "Layout", items: [
    { type: "note", label: "Note", icon: StickyNote },
    { type: "group", label: "Group", icon: FolderOpen },
    { type: "repeat", label: "Repeat", icon: Repeat },
  ]},
  { category: "Advanced", items: [
    { type: "calculation", label: "Calculation", icon: Calculator },
  ]},
];

function DraggableFieldType({ type, label, icon: Icon }: { type: string; label: string; icon: any }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: `palette-${type}`,
    data: { type, fromPalette: true },
  });

  return (
    <div
      ref={setNodeRef}
      {...listeners}
      {...attributes}
      className={`flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm cursor-grab hover:border-blue-300 hover:bg-blue-50 transition-colors ${isDragging ? "opacity-50" : ""}`}
    >
      <Icon className="h-4 w-4 text-gray-500" />
      <span className="text-gray-700">{label}</span>
    </div>
  );
}

export function FieldPalette() {
  return (
    <div className="w-56 border-r border-gray-200 bg-white overflow-y-auto p-3 flex flex-col gap-4">
      <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider px-1">Field Types</h3>
      {fieldTypes.map((cat) => (
        <div key={cat.category}>
          <p className="text-xs font-medium text-gray-500 mb-1.5 px-1">{cat.category}</p>
          <div className="flex flex-col gap-1">
            {cat.items.map((item) => (
              <DraggableFieldType key={item.type} {...item} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}