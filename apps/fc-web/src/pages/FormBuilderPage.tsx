import { useState, useCallback, useEffect } from "react";
import { useParams, Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  DndContext,
  DragOverlay,
  closestCenter,
  type DragStartEvent,
  type DragEndEvent,
} from "@dnd-kit/core";
import { arrayMove } from "@dnd-kit/sortable";
import { api } from "@/lib/api";
import { FieldPalette } from "@/components/form-builder/FieldPalette";
import { FormImportDialog } from "@/components/form-builder/FormImportDialog";
import { FormCanvas } from "@/components/form-builder/FormCanvas";
import { FieldSettingsPanel } from "@/components/form-builder/FieldSettingsPanel";
import { FormPreview } from "@/components/form-builder/FormPreview";
import { ArrowLeft, Save, Eye, EyeOff, Upload } from "lucide-react";

let fieldCounter = 0;

function generateFieldId(type: string): string {
  fieldCounter++;
  return type + "_" + fieldCounter;
}

function createDefaultField(type: string): any {
  const id = generateFieldId(type);
  const base: any = {
    id,
    type,
    label: { en: "" },
    required: false,
  };

  if (type === "select_one" || type === "select_multiple") {
    base.choices = [
      { value: "option_1", label: { en: "Option 1" } },
      { value: "option_2", label: { en: "Option 2" } },
    ];
  }

  if (type === "group" || type === "repeat") {
    base.children = [];
  }

  if (type === "photo") {
    base.appearance = "multi";
    base.constraints = { max_length: 10 };
  }

  return base;
}

export function FormBuilderPage() {
  const { projectId, formId } = useParams();
  const queryClient = useQueryClient();

  const [fields, setFields] = useState<any[]>([]);
  const [selectedFieldId, setSelectedFieldId] = useState<string | null>(null);
  const [formName, setFormName] = useState("");
  const [formDescription, setFormDescription] = useState("");
  const [activeId, setActiveId] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const [showImport, setShowImport] = useState(false);

  const { data: form } = useQuery({
    queryKey: ["form", formId],
    queryFn: () => api.getForm(projectId!, formId!),
    enabled: !!formId && !!projectId,
  });

  useEffect(() => {
    if (form) {
      setFormName(form.name || "");
      setFormDescription(form.description || "");
      const schema = form.schema;
      if (schema?.fields) {
        setFields(schema.fields);
        fieldCounter = schema.fields.length + 10;
      }
    }
  }, [form]);

  const saveMutation = useMutation({
    mutationFn: () =>
      api.updateForm(projectId!, formId!, {
        name: formName,
        description: formDescription,
        schema: {
          fields,
          settings: form?.schema?.settings || {
            default_language: "en",
            languages: ["en"],
          },
        },
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["form", formId] });
      queryClient.invalidateQueries({ queryKey: ["forms", projectId] });
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    },
  });

  const selectedField = fields.find((f) => f.id === selectedFieldId);

  const handleFieldChange = useCallback(
    (updated: any) => {
      setFields((prev) =>
        prev.map((f) => (f.id === selectedFieldId ? updated : f))
      );
      // If ID changed, update the selection to track the new ID
      if (updated.id !== selectedFieldId) {
        setSelectedFieldId(updated.id);
      }
    },
    [selectedFieldId]
  );

  const handleDeleteField = useCallback((id: string) => {
    setFields((prev) => prev.filter((f) => f.id !== id));
    setSelectedFieldId((prev) => (prev === id ? null : prev));
  }, []);

  const handleImportFields = useCallback((imported: any[]) => {
    setFields((prev) => [...prev, ...imported]);
    fieldCounter += imported.length;
    setShowImport(false);
  }, []);

  const handleDragStart = (event: DragStartEvent) => {
    setActiveId(String(event.active.id));
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setActiveId(null);
    const { active, over } = event;

    if (!over) return;

    if (active.data.current?.fromPalette) {
      const type = active.data.current.type;
      const newField = createDefaultField(type);
      setFields((prev) => [...prev, newField]);
      setSelectedFieldId(newField.id);
      return;
    }

    if (active.id !== over.id) {
      setFields((prev) => {
        const oldIndex = prev.findIndex((f) => f.id === active.id);
        const newIndex = prev.findIndex((f) => f.id === over.id);
        return arrayMove(prev, oldIndex, newIndex);
      });
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Top bar */}
      <div className="flex items-center gap-3 px-4 py-3 bg-white border-b border-gray-200 shrink-0">
        <Link
          to={"/projects/" + projectId + "/forms"}
          className="text-gray-400 hover:text-gray-600"
        >
          <ArrowLeft className="h-5 w-5" />
        </Link>
        <div className="flex-1 flex flex-col gap-0.5">
          <div className="flex items-center gap-3">
            <input
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
              className="text-lg font-semibold text-gray-900 border-none outline-none bg-transparent w-full"
              placeholder="Form name..."
            />
            <span className="text-xs text-gray-400 shrink-0">
              {fields.length} fields
            </span>
          </div>
          <input
            value={formDescription}
            onChange={(e) => setFormDescription(e.target.value)}
            className="text-sm text-gray-500 border-none outline-none bg-transparent w-full"
            placeholder="Add a description..."
          />
        </div>
        <div className="flex items-center gap-2">
          {saved && (
            <span className="text-xs text-green-600">Saved!</span>
          )}
          <button
            onClick={() => setShowImport(true)}
            className="flex items-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50"
          >
            <Upload className="h-4 w-4" />
            Import
          </button>
          <button
            onClick={() => setShowPreview(!showPreview)}
            className={
              "flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm transition-colors " +
              (showPreview
                ? "border-blue-300 bg-blue-50 text-blue-700"
                : "border-gray-300 text-gray-600 hover:bg-gray-50")
            }
          >
            {showPreview ? (
              <EyeOff className="h-4 w-4" />
            ) : (
              <Eye className="h-4 w-4" />
            )}
            Preview
          </button>
          <button
            onClick={() => saveMutation.mutate()}
            disabled={saveMutation.isPending}
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            <Save className="h-4 w-4" />
            {saveMutation.isPending ? "Saving..." : "Save"}
          </button>
        </div>
      </div>

      {/* Builder panels — all in one row, no nesting scroll */}
      <div className="flex flex-1 min-h-0">
        <DndContext
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <FieldPalette />
          <FormCanvas
            fields={fields}
            selectedFieldId={selectedFieldId}
            onSelectField={setSelectedFieldId}
            onDeleteField={handleDeleteField}
          />
          <DragOverlay>
            {activeId ? (
              <div className="rounded-lg border border-blue-300 bg-blue-50 px-4 py-2 text-sm shadow-lg">
                Dragging...
              </div>
            ) : null}
          </DragOverlay>
        </DndContext>

        {/* Settings panel — always visible */}
        {selectedField ? (
          <FieldSettingsPanel
            field={selectedField}
            onChange={handleFieldChange}
          />
        ) : (
          <div className="w-72 border-l border-gray-200 bg-white flex items-center justify-center shrink-0">
            <p className="text-sm text-gray-400 italic px-6 text-center">
              Select a field to edit its settings
            </p>
          </div>
        )}

        {/* Preview panel — slides in alongside when toggled */}
        {showPreview && (
          <div className="w-80 border-l border-gray-200 bg-gray-100 overflow-y-auto flex flex-col items-center p-4 shrink-0">
            <FormPreview fields={fields} formName={formName} />
          </div>
        )}
      </div>
      {showImport && (
        <FormImportDialog
          onImport={handleImportFields}
          onClose={() => setShowImport(false)}
        />
      )}
    </div>
  );
}