import { useDroppable } from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { SortableFieldCard } from "./SortableFieldCard";
import { FileText } from "lucide-react";

interface Props {
  fields: any[];
  selectedFieldId: string | null;
  onSelectField: (id: string) => void;
  onDeleteField: (id: string) => void;
}

export function FormCanvas({
  fields,
  selectedFieldId,
  onSelectField,
  onDeleteField,
}: Props) {
  const { setNodeRef, isOver } = useDroppable({ id: "form-canvas" });

  return (
    <div
      ref={setNodeRef}
      className={`flex-1 overflow-y-auto p-6 ${
        isOver ? "bg-blue-50" : "bg-gray-50"
      } transition-colors`}
    >
      {fields.length === 0 ? (
        <div className="flex flex-col items-center justify-center h-full text-gray-400">
          <FileText className="h-12 w-12 mb-3" />
          <p className="text-lg font-medium">No fields yet</p>
          <p className="text-sm">
            Drag fields from the palette to start building your form
          </p>
        </div>
      ) : (
        <SortableContext
          items={fields.map((f) => f.id)}
          strategy={verticalListSortingStrategy}
        >
          <div className="max-w-2xl mx-auto flex flex-col gap-2">
            {fields.map((field) => (
              <SortableFieldCard
                key={field.id}
                field={field}
                isSelected={selectedFieldId === field.id}
                onSelect={() => onSelectField(field.id)}
                onDelete={() => onDeleteField(field.id)}
              />
            ))}
          </div>
        </SortableContext>
      )}
    </div>
  );
}