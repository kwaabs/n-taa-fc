import { useState } from "react";
import { MapPin, Camera, Mic, QrCode } from "lucide-react";

interface Props {
  fields: any[];
  formName: string;
  /** Extra classes on the phone frame (e.g. h-full max-h-full). */
  className?: string;
}

function PreviewField({ field, values, onChange }: {
  field: any;
  values: Record<string, any>;
  onChange: (id: string, value: any) => void;
}) {
  const label = field.label?.en || field.id;
  const hint = field.description?.en;
  const required = field.required;
  const value = values[field.id] ?? "";

  return (
    <div className="mb-4">
      {field.type !== "note" && (
        <label className="block text-sm font-medium text-gray-800 mb-1">
          {label}
          {required && <span className="text-red-500 ml-0.5">*</span>}
        </label>
      )}

      {hint && <p className="text-xs text-gray-400 mb-1.5">{hint}</p>}

      {/* Text */}
      {field.type === "text" && field.appearance === "multiline" && (
        <textarea
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          placeholder={"Enter " + label}
          rows={3}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}
      {field.type === "text" && field.appearance !== "multiline" && (
        <input
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          placeholder={"Enter " + label}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}

      {/* Numbers */}
      {(field.type === "integer" || field.type === "decimal") && (
        <input
          type="number"
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          placeholder="0"
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}

      {/* Select One — dropdown */}
      {field.type === "select_one" && (field.appearance === "dropdown" || !field.appearance) && (
        <select
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Select...</option>
          {(field.choices || []).map((c: any) => (
            <option key={c.value} value={c.value}>
              {c.label?.en || c.value}
            </option>
          ))}
        </select>
      )}

      {/* Select One — radio */}
      {field.type === "select_one" && (field.appearance === "radio" || field.appearance === "likert") && (
        <div className="flex flex-col gap-2">
          {(field.choices || []).map((c: any) => (
            <label key={c.value} className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
              <input
                type="radio"
                name={"preview_" + field.id}
                value={c.value}
                checked={value === c.value}
                onChange={() => onChange(field.id, c.value)}
                className="rounded-full border-gray-300 text-blue-600"
              />
              {c.label?.en || c.value}
            </label>
          ))}
        </div>
      )}

      {/* Select Multiple */}
      {field.type === "select_multiple" && (
        <div className="flex flex-col gap-2">
          {(field.choices || []).map((c: any) => {
            const selected = Array.isArray(value) ? value : [];
            const isChecked = selected.includes(c.value);
            return (
              <label key={c.value} className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isChecked}
                  onChange={() => {
                    const next = isChecked
                      ? selected.filter((v: string) => v !== c.value)
                      : [...selected, c.value];
                    onChange(field.id, next);
                  }}
                  className="rounded border-gray-300 text-blue-600"
                />
                {c.label?.en || c.value}
              </label>
            );
          })}
        </div>
      )}

      {/* Date / Time */}
      {field.type === "date" && (
        <input
          type="date"
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}
      {field.type === "datetime" && (
        <input
          type="datetime-local"
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}
      {field.type === "time" && (
        <input
          type="time"
          value={value}
          onChange={(e) => onChange(field.id, e.target.value)}
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      )}

      {/* GPS */}
      {(field.type === "geopoint" || field.type === "geotrace" || field.type === "geoshape") && (
        <button
          onClick={() => onChange(field.id, "0.0000, 0.0000")}
          className={
            "flex items-center gap-2 w-full rounded-lg border px-4 py-3 text-sm transition-colors " +
            (value
              ? "border-green-300 bg-green-50 text-green-700"
              : "border-dashed border-gray-300 bg-white text-gray-500 hover:border-blue-300 hover:bg-blue-50")
          }
        >
          <MapPin className="h-4 w-4" />
          {value ? "Location captured: " + value : field.type === "geopoint" ? "Capture GPS Location" : field.type === "geotrace" ? "Record GPS Trace" : "Draw GPS Shape"}
        </button>
      )}

      {/* Photo — up to 10 captures */}
      {field.type === "photo" && (() => {
        const maxPhotos = Math.min(
          10,
          Math.max(1, Number(field.constraints?.max_length) || 10),
        );
        const photos: string[] = Array.isArray(value)
          ? value
          : typeof value === "string" && value
            ? value.split(",").filter(Boolean)
            : [];
        const canAdd = photos.length < maxPhotos;
        return (
          <div className="space-y-2">
            <div className="flex flex-wrap gap-2">
              {photos.map((p: string, i: number) => (
                <div
                  key={i}
                  className="relative h-16 w-16 rounded-lg border border-green-300 bg-green-50 flex items-center justify-center"
                >
                  <Camera className="h-5 w-5 text-green-700" />
                  <button
                    type="button"
                    onClick={() => {
                      const next = photos.filter((_: string, j: number) => j !== i);
                      onChange(field.id, next.length ? next.join(",") : "");
                    }}
                    className="absolute -top-1.5 -right-1.5 h-5 w-5 rounded-full bg-red-500 text-white text-[10px] leading-5"
                    title="Remove"
                  >
                    ×
                  </button>
                </div>
              ))}
              {canAdd && (
                <button
                  type="button"
                  onClick={() =>
                    onChange(
                      field.id,
                      [...photos, `photo_${photos.length + 1}.jpg`].join(","),
                    )
                  }
                  className="h-16 w-16 rounded-lg border border-dashed border-gray-300 bg-white text-gray-500 hover:border-blue-300 hover:bg-blue-50 flex flex-col items-center justify-center gap-0.5"
                >
                  <Camera className="h-4 w-4" />
                  <span className="text-[10px]">Add</span>
                </button>
              )}
            </div>
            <p className="text-[11px] text-gray-400">
              {photos.length} / {maxPhotos} photos
            </p>
          </div>
        );
      })()}

      {/* Audio */}
      {field.type === "audio" && (
        <button
          onClick={() => onChange(field.id, value ? "" : "recording.m4a")}
          className={
            "flex items-center gap-2 w-full rounded-lg border px-4 py-3 text-sm transition-colors " +
            (value
              ? "border-green-300 bg-green-50 text-green-700"
              : "border-dashed border-gray-300 bg-white text-gray-500 hover:border-blue-300 hover:bg-blue-50")
          }
        >
          <Mic className="h-4 w-4" />
          {value ? "Audio recorded" : "Record Audio"}
        </button>
      )}

      {/* Barcode */}
      {field.type === "barcode" && (
        <button
          onClick={() => onChange(field.id, value ? "" : "ABC-1234-XYZ")}
          className={
            "flex items-center gap-2 w-full rounded-lg border px-4 py-3 text-sm transition-colors " +
            (value
              ? "border-green-300 bg-green-50 text-green-700"
              : "border-dashed border-gray-300 bg-white text-gray-500 hover:border-blue-300 hover:bg-blue-50")
          }
        >
          <QrCode className="h-4 w-4" />
          {value ? "Scanned: " + value : "Scan Barcode"}
        </button>
      )}

      {/* Note */}
      {field.type === "note" && (
        <p className="text-sm text-gray-600 bg-blue-50 rounded-lg px-3 py-2 border border-blue-100">
          {label}
        </p>
      )}

      {/* Calculation */}
      {field.type === "calculation" && (
        <div className="rounded-lg bg-gray-100 px-3 py-2 text-sm text-gray-500 font-mono">
          = {field.calculation || "expression"}
        </div>
      )}

      {/* Group */}
      {field.type === "group" && (
        <div className="border border-gray-200 rounded-lg p-3 bg-gray-50/50 mt-1">
          <p className="text-xs font-medium text-gray-500 mb-2 uppercase">{label}</p>
          {(field.children || []).length === 0 ? (
            <p className="text-xs text-gray-400 italic">Empty group</p>
          ) : (
            (field.children || []).map((child: any) => (
              <PreviewField key={child.id} field={child} values={values} onChange={onChange} />
            ))
          )}
        </div>
      )}

      {/* Repeat */}
      {field.type === "repeat" && (
        <div className="border border-orange-200 rounded-lg p-3 bg-orange-50/30 mt-1">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs font-medium text-orange-600 uppercase">{label} (repeating)</p>
            <span className="text-xs text-orange-500 cursor-pointer hover:underline">+ Add entry</span>
          </div>
          {(field.children || []).length === 0 ? (
            <p className="text-xs text-gray-400 italic">Empty repeat group</p>
          ) : (
            (field.children || []).map((child: any) => (
              <PreviewField key={child.id} field={child} values={values} onChange={onChange} />
            ))
          )}
        </div>
      )}

      {/* Validation feedback */}
      {required && !value && values._submitted && (
        <p className="text-xs text-red-500 mt-1">This field is required</p>
      )}
    </div>
  );
}

export function FormPreview({ fields, formName, className }: Props) {
  const [values, setValues] = useState<Record<string, any>>({});

  const handleChange = (id: string, value: any) => {
    setValues((prev) => ({ ...prev, [id]: value }));
  };

  const handleSubmit = () => {
    setValues((prev) => ({ ...prev, _submitted: true }));
    const missing = fields
      .filter((f) => f.required && !values[f.id])
      .map((f) => f.label?.en || f.id);

    if (missing.length > 0) {
      alert("Missing required fields:\n- " + missing.join("\n- "));
    } else {
      alert("Form submitted!\n\n" + JSON.stringify(values, null, 2));
    }
  };

  const handleReset = () => {
    setValues({});
  };

  return (
    <div
      className={
        "w-full max-w-[320px] bg-white rounded-2xl shadow-lg border border-gray-200 overflow-hidden flex flex-col " +
        (className ?? "max-h-[calc(100vh-12rem)]")
      }
    >
      {/* Status bar */}
      <div className="bg-gray-900 text-white text-xs px-4 py-1.5 flex justify-between shrink-0">
        <span>9:41</span>
        <span>Live Preview</span>
        <span>100%</span>
      </div>

      {/* Header */}
      <div className="bg-blue-600 text-white px-4 py-3 shrink-0">
        <h3 className="font-medium text-sm">{formName || "Untitled Form"}</h3>
        <p className="text-xs text-blue-200 mt-0.5">
          {fields.length} fields
          {Object.keys(values).filter((k) => k !== "_submitted").length > 0 &&
            " · " +
              Object.keys(values).filter((k) => k !== "_submitted").length +
              " filled"}
        </p>
      </div>

      {/* Form body */}
      <div className="flex-1 overflow-y-auto p-4">
        {fields.length === 0 ? (
          <p className="text-sm text-gray-400 text-center py-8 italic">
            Add fields to see the preview
          </p>
        ) : (
          fields.map((field) => (
            <PreviewField
              key={field.id}
              field={field}
              values={values}
              onChange={handleChange}
            />
          ))
        )}
      </div>

      {/* Footer */}
      {fields.length > 0 && (
        <div className="border-t border-gray-200 px-4 py-3 flex gap-2 shrink-0">
          <button
            onClick={handleReset}
            className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
          >
            Clear
          </button>
          <button
            onClick={handleSubmit}
            className="flex-1 rounded-lg bg-blue-600 px-3 py-2.5 text-sm font-medium text-white hover:bg-blue-700"
          >
            Submit
          </button>
        </div>
      )}
    </div>
  );
}