import { Asterisk, Settings2, Pencil } from "lucide-react";
import { FieldTypeChip } from "./FieldTypeChip";
import { isSystemFieldId } from "@/lib/system-fields";

interface Field {
  id: string;
  type: string;
  label?: { en?: string } | string;
  description?: { en?: string } | string;
  required?: boolean;
  appearance?: string;
  choices?: Array<{
    value: string;
    label?: { en?: string } | string;
  }>;
}

interface Props {
  field: Field;
  index: number;
  onClick?: (field: Field) => void;
}

function asText(v: any): string | null {
  if (!v) return null;
  if (typeof v === "string") return v;
  if (typeof v === "object" && typeof v.en === "string") return v.en;
  return null;
}

export function FieldRow({ field, index, onClick }: Props) {
  const isSystem = isSystemFieldId(field.id);
  const label = asText(field.label) ?? field.id;
  const description = asText(field.description);
  const choiceCount = field.choices?.length ?? 0;

  const clickable = !!onClick;

  return (
    <div
      role={clickable ? "button" : undefined}
      tabIndex={clickable ? 0 : undefined}
      onClick={clickable ? () => onClick!(field) : undefined}
      onKeyDown={
        clickable
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onClick!(field);
              }
            }
          : undefined
      }
      className={
        "group rounded-lg border px-3 py-2.5 transition-colors " +
        (isSystem
          ? "border-gray-100 bg-gray-50/60"
          : "border-gray-200 bg-white hover:border-blue-300 hover:bg-blue-50/40") +
        (clickable ? " cursor-pointer" : "")
      }
    >
      <div className="flex items-center gap-2">
        {/* Sequence number */}
        <span className="text-xs text-gray-400 w-6 text-right tabular-nums">
          {index + 1}.
        </span>

        {/* Type chip */}
        <FieldTypeChip type={field.type} />

        {/* Label + id + description */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <span
              className={
                "text-sm truncate " +
                (isSystem
                  ? "text-gray-500"
                  : "text-gray-900 font-medium")
              }
            >
              {label}
            </span>
            {field.required && (
              <Asterisk className="h-3 w-3 text-red-500 shrink-0" />
            )}
            {isSystem && (
              <span className="flex items-center gap-0.5 rounded-full bg-amber-50 border border-amber-100 px-1.5 py-0.5 text-[10px] text-amber-700 shrink-0">
                <Settings2 className="h-2.5 w-2.5" />
                system
              </span>
            )}
          </div>
          <div className="flex items-center gap-2 mt-0.5">
            <span className="text-[11px] font-mono text-gray-400 truncate">
              {field.id}
            </span>
            {field.appearance && (
              <span className="text-[10px] uppercase tracking-wide text-gray-400 shrink-0">
                · {field.appearance}
              </span>
            )}
            {choiceCount > 0 && (
              <span className="text-[10px] text-gray-400 shrink-0">
                · {choiceCount} option{choiceCount === 1 ? "" : "s"}
              </span>
            )}
          </div>
          {description && (
            <p className="text-xs text-gray-500 italic truncate mt-0.5">
              {description}
            </p>
          )}
        </div>

        {/* Edit affordance */}
        {clickable && (
          <Pencil
            className={
              "h-4 w-4 shrink-0 transition-opacity " +
              (isSystem
                ? "text-gray-300"
                : "text-gray-300 group-hover:text-blue-500")
            }
          />
        )}
      </div>
    </div>
  );
}