import { useState } from "react";
import { Upload, FileJson, FileSpreadsheet, X, BookTemplate } from "lucide-react";

interface Props {
  onImport: (fields: any[]) => void;
  onClose: () => void;
}

// ── Templates ──────────────────────────────────────

const csvTemplates = [
  {
    name: "Water Point Survey",
    description: "Inspect water sources, track functionality",
    csv: `type,id,label,required,choices,description
text,water_point_name,Water Point Name,true,,
select_one,water_source_type,Source Type,true,borehole|Borehole;well|Hand-dug Well;spring|Spring;tap|Tap Stand,,
select_one,functionality,Functionality,true,functional|Functional;partial|Partially Functional;broken|Non-functional,,
integer,population_served,Population Served,false,,,
select_multiple,problems,Problems Observed,false,leaking|Leaking;contaminated|Contaminated;low_yield|Low Yield;broken_pump|Broken Pump,,
date,inspection_date,Inspection Date,true,,
geopoint,location,GPS Location,true,,
photo,site_photo,Site Photo,true,,
text,notes,Additional Notes,false,,`,
  },
  {
    name: "Household Survey",
    description: "Collect household demographics and assets",
    csv: `type,id,label,required,choices,description
text,household_head,Head of Household,true,,Full name
integer,household_size,Household Size,true,,,
select_one,dwelling_type,Dwelling Type,true,permanent|Permanent;semi_permanent|Semi-permanent;temporary|Temporary,,
select_multiple,water_sources,Water Sources Used,true,piped|Piped Water;borehole|Borehole;river|River;rainwater|Rainwater,,
select_one,toilet_type,Toilet Type,true,flush|Flush;pit_latrine|Pit Latrine;none|None,,
integer,monthly_income,Monthly Income,false,,,
geopoint,location,GPS Location,true,,
photo,dwelling_photo,Photo of Dwelling,false,,
text,notes,Notes,false,,`,
  },
  {
    name: "School Mapping",
    description: "Map schools with infrastructure details",
    csv: `type,id,label,required,choices,description
text,school_name,School Name,true,,
select_one,school_type,School Type,true,primary|Primary;secondary|Secondary;vocational|Vocational,,
text,head_teacher,Head Teacher Name,false,,
integer,total_students,Total Students,true,,,
integer,total_teachers,Total Teachers,true,,,
integer,num_classrooms,Number of Classrooms,true,,,
select_one,water_available,Water Available,true,yes|Yes;no|No,,
select_one,electricity,Electricity,true,grid|Grid;solar|Solar;none|None,,
geopoint,location,GPS Location,true,,
photo,school_photo,School Photo,true,,`,
  },
];

const jsonTemplates = [
  {
    name: "Basic Inspection",
    description: "Simple inspection form with GPS and photo",
    json: JSON.stringify({
      fields: [
        { id: "name", type: "text", label: { en: "Site Name" }, required: true },
        { id: "status", type: "select_one", label: { en: "Status" }, required: true, choices: [
          { value: "good", label: { en: "Good" } },
          { value: "fair", label: { en: "Fair" } },
          { value: "poor", label: { en: "Poor" } },
        ]},
        { id: "notes", type: "text", label: { en: "Notes" }, appearance: "multiline" },
        { id: "location", type: "geopoint", label: { en: "GPS Location" }, required: true },
        { id: "photo", type: "photo", label: { en: "Site Photo" }, required: true },
      ],
      settings: { default_language: "en", languages: ["en"] },
    }, null, 2),
  },
  {
    name: "Health Facility Assessment",
    description: "Assess health facility services and infrastructure",
    json: JSON.stringify({
      fields: [
        { id: "facility_name", type: "text", label: { en: "Facility Name" }, required: true },
        { id: "facility_type", type: "select_one", label: { en: "Facility Type" }, required: true, choices: [
          { value: "hospital", label: { en: "Hospital" } },
          { value: "clinic", label: { en: "Clinic" } },
          { value: "health_post", label: { en: "Health Post" } },
        ]},
        { id: "num_beds", type: "integer", label: { en: "Number of Beds" }, constraints: { min: 0 } },
        { id: "num_staff", type: "integer", label: { en: "Number of Staff" }, constraints: { min: 0 } },
        { id: "services", type: "select_multiple", label: { en: "Services Available" }, choices: [
          { value: "maternity", label: { en: "Maternity" } },
          { value: "surgery", label: { en: "Surgery" } },
          { value: "lab", label: { en: "Laboratory" } },
          { value: "pharmacy", label: { en: "Pharmacy" } },
          { value: "vaccination", label: { en: "Vaccination" } },
        ]},
        { id: "has_electricity", type: "select_one", label: { en: "Electricity" }, choices: [
          { value: "grid", label: { en: "Grid" } },
          { value: "solar", label: { en: "Solar" } },
          { value: "generator", label: { en: "Generator" } },
          { value: "none", label: { en: "None" } },
        ]},
        { id: "location", type: "geopoint", label: { en: "GPS Location" }, required: true },
        { id: "photo", type: "photo", label: { en: "Facility Photo" } },
      ],
      settings: { default_language: "en", languages: ["en"] },
    }, null, 2),
  },
];

// ── Parsers ────────────────────────────────────────

function parseCSVLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (ch === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  result.push(current);
  return result;
}

function parseCSV(text: string): any[] {
  const lines = text.trim().split("\n");
  if (lines.length < 2) return [];

  const headers = lines[0].split(",").map((h) => h.trim().toLowerCase());
  const fields: any[] = [];

  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVLine(lines[i]);
    const row: Record<string, string> = {};
    headers.forEach((h, idx) => {
      row[h] = (values[idx] || "").trim();
    });

    if (!row.type || !row.id) continue;

    const field: any = {
      id: row.id,
      type: row.type,
      label: { en: row.label || row.name || row.id },
      required: row.required === "true" || row.required === "yes" || row.required === "1",
    };

    if (row.description || row.hint) {
      field.description = { en: row.description || row.hint };
    }
    if (row.appearance) field.appearance = row.appearance;
    if (row.default) field.default = row.default;
    if (row.relevant) field.relevant = row.relevant;
    if (row.calculation) field.calculation = row.calculation;

    if (row.choices) {
      field.choices = row.choices.split(";").map((pair) => {
        const parts = pair.trim().split("|");
        return {
          value: parts[0]?.trim() || "",
          label: { en: parts[1]?.trim() || parts[0]?.trim() || "" },
        };
      });
    }

    const constraints: any = {};
    if (row.min) constraints.min = Number(row.min);
    if (row.max) constraints.max = Number(row.max);
    if (row.min_length) constraints.min_length = Number(row.min_length);
    if (row.max_length) constraints.max_length = Number(row.max_length);
    if (row.pattern) constraints.pattern = row.pattern;
    if (Object.keys(constraints).length > 0) {
      field.constraints = constraints;
    }

    fields.push(field);
  }

  return fields;
}

function parseJSON(text: string): any[] {
  const parsed = JSON.parse(text);
  if (parsed.fields && Array.isArray(parsed.fields)) return parsed.fields;
  if (Array.isArray(parsed)) return parsed;
  throw new Error("JSON must have a 'fields' array or be a plain array of fields");
}

// ── Component ──────────────────────────────────────

const defaultCSV = `type,id,label,required,choices,description,min,max,pattern
text,respondent_name,Respondent Name,true,,Full name,,,
integer,age,Age,true,,,0,120,
select_one,gender,Gender,true,male|Male;female|Female;other|Other,,,,
date,visit_date,Visit Date,true,,Date of visit,,,
geopoint,location,GPS Location,true,,,,
photo,site_photo,Site Photo,false,,,,`;

export function FormImportDialog({ onImport, onClose }: Props) {
  const [mode, setMode] = useState<"json" | "csv">("csv");
  const [text, setText] = useState(defaultCSV);
  const [error, setError] = useState("");
  const [preview, setPreview] = useState<any[] | null>(null);

  const handleParse = () => {
    setError("");
    setPreview(null);
    try {
      const fields = mode === "csv" ? parseCSV(text) : parseJSON(text);
      if (fields.length === 0) {
        setError("No valid fields found. Check your format.");
        return;
      }
      setPreview(fields);
    } catch (err: any) {
      setError(err.message || "Failed to parse input");
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (ev) => {
      const content = ev.target?.result as string;
      setText(content);
      if (file.name.endsWith(".json")) {
        setMode("json");
      } else {
        setMode("csv");
      }
      setPreview(null);
      setError("");
    };
    reader.readAsText(file);
  };

  const handleImport = () => {
    if (preview) {
      onImport(preview);
    }
  };

  const loadTemplate = (content: string, format: "csv" | "json") => {
    setMode(format);
    setText(content);
    setError("");
    setPreview(null);
  };

  const currentTemplates = mode === "csv" ? csvTemplates : jsonTemplates;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[85vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 shrink-0">
          <div className="flex items-center gap-3">
            <Upload className="h-5 w-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-gray-900">Import Form</h2>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-auto p-6 flex flex-col gap-5">
          {/* Format toggle + file upload */}
          <div className="flex items-center gap-3">
            <div className="flex rounded-lg border border-gray-200 overflow-hidden">
              <button
                onClick={() => {
                  setMode("csv");
                  if (text.trim().startsWith("{") || text.trim().startsWith("[")) {
                    setText(defaultCSV);
                  }
                  setPreview(null);
                  setError("");
                }}
                className={
                  "flex items-center gap-1.5 px-4 py-2 text-sm font-medium " +
                  (mode === "csv"
                    ? "bg-blue-50 text-blue-700"
                    : "text-gray-600 hover:bg-gray-50")
                }
              >
                <FileSpreadsheet className="h-4 w-4" /> CSV Format
              </button>
              <button
                onClick={() => {
                  setMode("json");
                  if (!text.trim().startsWith("{") && !text.trim().startsWith("[")) {
                    setText("");
                  }
                  setPreview(null);
                  setError("");
                }}
                className={
                  "flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-l border-gray-200 " +
                  (mode === "json"
                    ? "bg-blue-50 text-blue-700"
                    : "text-gray-600 hover:bg-gray-50")
                }
              >
                <FileJson className="h-4 w-4" /> JSON Format
              </button>
            </div>

            <label className="flex items-center gap-2 rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50 cursor-pointer">
              <Upload className="h-4 w-4" /> Upload File
              <input
                type="file"
                accept=".csv,.json,.txt"
                onChange={handleFileUpload}
                className="hidden"
              />
            </label>
          </div>

          {/* Templates */}
          <div>
            <div className="flex items-center gap-2 mb-2">
              <BookTemplate className="h-4 w-4 text-gray-500" />
              <p className="text-sm font-medium text-gray-700">
                {mode === "csv" ? "CSV" : "JSON"} Templates
              </p>
              <span className="text-xs text-gray-400">— click to load</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {currentTemplates.map((tpl) => {
                const content = mode === "csv" ? (tpl as any).csv : (tpl as any).json;
                const fieldCount = mode === "csv"
                  ? content.trim().split("\n").length - 1
                  : JSON.parse(content).fields?.length || 0;
                return (
                  <button
                    key={tpl.name}
                    onClick={() => loadTemplate(content, mode)}
                    className="rounded-lg border border-gray-200 bg-white px-3 py-2.5 text-left hover:border-blue-300 hover:bg-blue-50 transition-colors"
                  >
                    <p className="text-sm font-medium text-gray-900">{tpl.name}</p>
                    <p className="text-xs text-gray-500 mt-0.5">{tpl.description}</p>
                    <p className="text-xs text-gray-400 mt-1">{fieldCount} fields · {mode.toUpperCase()}</p>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Format help */}
          {mode === "csv" && (
            <div className="bg-gray-50 rounded-lg px-4 py-3 text-xs text-gray-600">
              <p className="font-medium mb-1">CSV Column Reference:</p>
              <p>
                <code className="bg-gray-200 px-1 rounded">type</code>{" "}
                <code className="bg-gray-200 px-1 rounded">id</code>{" "}
                <code className="bg-gray-200 px-1 rounded">label</code>{" "}
                <code className="bg-gray-200 px-1 rounded">required</code>{" "}
                <code className="bg-gray-200 px-1 rounded">choices</code>{" "}
                <code className="bg-gray-200 px-1 rounded">description</code>{" "}
                <code className="bg-gray-200 px-1 rounded">min</code>{" "}
                <code className="bg-gray-200 px-1 rounded">max</code>{" "}
                <code className="bg-gray-200 px-1 rounded">pattern</code>{" "}
                <code className="bg-gray-200 px-1 rounded">relevant</code>{" "}
                <code className="bg-gray-200 px-1 rounded">default</code>{" "}
                <code className="bg-gray-200 px-1 rounded">appearance</code>
              </p>
              <p className="mt-1">
                Choices: <code className="bg-gray-200 px-1 rounded">value1|Label 1;value2|Label 2</code>
              </p>
            </div>
          )}
          {mode === "json" && (
            <div className="bg-gray-50 rounded-lg px-4 py-3 text-xs text-gray-600">
              <p className="font-medium mb-1">JSON Format:</p>
              <p>
                Schema: <code className="bg-gray-200 px-1 rounded">{"{ \"fields\": [...] }"}</code> or
                Array: <code className="bg-gray-200 px-1 rounded">{"[{ \"id\": ..., \"type\": ... }]"}</code>
              </p>
            </div>
          )}

          {/* Text area — always visible */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="text-sm font-medium text-gray-700">
                {mode === "csv" ? "CSV" : "JSON"} Content
              </label>
              <span className="text-xs text-gray-400">
                {text.trim().split("\n").length} lines
              </span>
            </div>
            <textarea
              value={text}
              onChange={(e) => {
                setText(e.target.value);
                setPreview(null);
                setError("");
              }}
              rows={10}
              placeholder={
                mode === "csv"
                  ? "Paste CSV here, upload a file, or pick a template above..."
                  : "Paste JSON here, upload a file, or pick a template above..."
              }
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm font-mono resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {error && <p className="text-sm text-red-600">{error}</p>}

          {/* Preview */}
          {preview && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <p className="text-sm font-medium text-green-800 mb-2">
                Parsed {preview.length} fields successfully:
              </p>
              <div className="flex flex-col gap-1 max-h-40 overflow-y-auto">
                {preview.map((f, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-2 text-xs text-green-700"
                  >
                    <span className="rounded bg-green-100 px-1.5 py-0.5 font-mono">
                      {f.type}
                    </span>
                    <span className="font-medium">{f.id}</span>
                    <span className="text-green-600">{f.label?.en || ""}</span>
                    {f.required && (
                      <span className="text-red-500">*required</span>
                    )}
                    {f.choices && (
                      <span className="text-green-500">
                        ({f.choices.length} choices)
                      </span>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200 shrink-0">
          <p className="text-xs text-gray-400">
            Imported fields will be added to the current form
          </p>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="rounded-lg border border-gray-300 px-4 py-2 text-sm"
            >
              Cancel
            </button>
            {!preview ? (
              <button
                onClick={handleParse}
                disabled={!text.trim()}
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
              >
                Parse
              </button>
            ) : (
              <button
                onClick={handleImport}
                className="rounded-lg bg-green-600 px-4 py-2 text-sm text-white hover:bg-green-700"
              >
                Import {preview.length} Fields
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}