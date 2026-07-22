import { useMemo, useState } from "react";
import { Copy } from "lucide-react";
interface Props {
    conflict: any;
    onCancel: () => void;
    onSave: (merged: Record<string, any>) => void;
    saving?: boolean;
}

type Pick = "source" | "field" | "original" | "custom";

interface FieldState {
    pick: Pick;
    customValue: string;
}

/**
 * ManualMergeEditor renders a per-field merge form: for every field present
 * across the 3 sides (original snapshot / surveyor edit / current source),
 * admin picks which value to keep — or types a custom one. Result is a single
 * resolved_attrs object submitted to the backend.
 */
export function ManualMergeEditor({
    conflict,
    onCancel,
    onSave,
    saving,
}: Props) {
    const origAttrs = conflict.original_attrs ?? {};
    const fieldAttrs = conflict.field_attrs ?? {};
    const sourceAttrs = conflict.source_attrs ?? {};
    const conflicting = new Set<string>(conflict.conflicting_fields ?? []);
    const changeType = conflict.change_type as string;

    // Union of all keys across the 3 sides
    const allKeys = useMemo(
        () =>
            Array.from(
                new Set<string>([
                    ...Object.keys(origAttrs),
                    ...Object.keys(fieldAttrs),
                    ...Object.keys(sourceAttrs),
                ])
            ).sort(),
        [origAttrs, fieldAttrs, sourceAttrs]
    );

    // Default pick per field: prefer surveyor's edit on conflicting fields,
    // otherwise prefer source's current value (= "leave it alone" baseline).
    const initialState = useMemo<Record<string, FieldState>>(() => {
        const out: Record<string, FieldState> = {};
        for (const k of allKeys) {
            const defaultPick: Pick = conflicting.has(k)
                ? fieldAttrs[k] !== undefined
                    ? "field"
                    : "source"
                : "source";
            out[k] = { pick: defaultPick, customValue: "" };
        }
        return out;
    }, [allKeys, conflicting, fieldAttrs]);

    const [state, setState] = useState<Record<string, FieldState>>(initialState);
    const [showAll, setShowAll] = useState(false);

    const visibleKeys = showAll
        ? allKeys
        : allKeys.filter((k) => conflicting.has(k));

    const setPick = (key: string, pick: Pick) => {
        setState({ ...state, [key]: { ...state[key], pick } });
    };

    const setCustomValue = (key: string, customValue: string) => {
        setState({
            ...state,
            [key]: { ...state[key], pick: "custom", customValue },
        });
    };

    const buildMerged = (): Record<string, any> => {
        const merged: Record<string, any> = {};
        for (const k of allKeys) {
            const s = state[k];
            switch (s.pick) {
                case "source":
                    if (sourceAttrs[k] !== undefined) merged[k] = sourceAttrs[k];
                    break;
                case "field":
                    if (fieldAttrs[k] !== undefined) merged[k] = fieldAttrs[k];
                    break;
                case "original":
                    if (origAttrs[k] !== undefined) merged[k] = origAttrs[k];
                    break;
                case "custom":
                    merged[k] = parseCustom(s.customValue);
                    break;
            }
        }
        return merged;
    };

    return (
        <div className="flex flex-col gap-3">
            {/* Filter toggle */}
            <div className="flex items-center justify-between">
                <p className="text-xs text-gray-500">
                    Picking values for {visibleKeys.length} of {allKeys.length} fields
                </p>
                <button
                    onClick={() => setShowAll(!showAll)}
                    className="text-xs text-blue-600 hover:underline"
                >
                    {showAll ? "Show only conflicting" : "Show all fields"}
                </button>
            </div>

            {/* Field-by-field picker */}
            <div className="flex flex-col gap-1.5 max-h-[400px] overflow-y-auto">
                {visibleKeys.map((k) => (
                    <FieldPicker
                        key={k}
                        fieldKey={k}
                        isConflict={conflicting.has(k)}
                        originalValue={origAttrs[k]}
                        fieldValue={changeType === "deleted" ? undefined : fieldAttrs[k]}
                        sourceValue={sourceAttrs[k]}
                        state={state[k]}
                        onPick={(p) => setPick(k, p)}
                        onCustom={(v) => setCustomValue(k, v)}
                    />
                ))}
                {visibleKeys.length === 0 && (
                    <p className="text-xs text-gray-400 italic text-center py-4">
                        No fields to merge
                    </p>
                )}
            </div>

            {/* Action buttons */}
            <div className="flex gap-2 pt-2 border-t border-gray-200">
                <button
                    onClick={onCancel}
                    className="flex-1 rounded-lg border border-gray-300 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50"
                >
                    Cancel
                </button>
                <button
                    onClick={() => onSave(buildMerged())}
                    disabled={saving}
                    className="flex-1 rounded-lg bg-blue-600 px-3 py-2 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                >
                    {saving ? "Saving…" : "Save merge"}
                </button>
            </div>
        </div>
    );
}

function FieldPicker({
    fieldKey,
    isConflict,
    originalValue,
    fieldValue,
    sourceValue,
    state,
    onPick,
    onCustom,
}: {
    fieldKey: string;
    isConflict: boolean;
    originalValue: any;
    fieldValue: any;
    sourceValue: any;
    state: FieldState;
    onPick: (p: Pick) => void;
    onCustom: (v: string) => void;
}) {
    return (
        <div
            className={
                "rounded-lg border p-2.5 " +
                (isConflict
                    ? "border-amber-200 bg-amber-50/40"
                    : "border-gray-100 bg-white")
            }
        >
            <p className="text-xs font-mono font-medium text-gray-900 mb-1.5">
                {fieldKey}
                {isConflict && (
                    <span className="ml-1 text-[10px] text-amber-700 font-sans">
                        ● conflict
                    </span>
                )}
            </p>

            <div className="space-y-1">
                {sourceValue !== undefined && (
                    <PickRow
                        label="Source"
                        value={sourceValue}
                        selected={state.pick === "source"}
                        onClick={() => onPick("source")}
                        onCopy={() => onCustom(formatValue(sourceValue))}
                    />
                )}
                {fieldValue !== undefined && (
                    <PickRow
                        label="Surveyor"
                        value={fieldValue}
                        selected={state.pick === "field"}
                        onClick={() => onPick("field")}
                        onCopy={() => onCustom(formatValue(fieldValue))}
                    />
                )}
                {originalValue !== undefined &&
                    originalValue !== sourceValue &&
                    originalValue !== fieldValue && (
                        <PickRow
                            label="Original"
                            value={originalValue}
                            selected={state.pick === "original"}
                            onClick={() => onPick("original")}
                            onCopy={() => onCustom(formatValue(originalValue))}
                        />
                    )}

                {/* Custom input */}
                <label className="flex items-start gap-2 cursor-pointer px-1.5 py-1 rounded hover:bg-white">
                    <input
                        type="radio"
                        checked={state.pick === "custom"}
                        onChange={() => onPick("custom")}
                        className="mt-0.5"
                    />
                    <span className="text-[10px] text-gray-500 shrink-0 mt-0.5 w-14">
                        Custom
                    </span>
                    <input
                        type="text"
                        value={state.customValue}
                        onChange={(e) => onCustom(e.target.value)}
                        placeholder="type a value…"
                        className="flex-1 text-xs rounded border border-gray-200 px-1.5 py-0.5 font-mono"
                    />
                </label>
            </div>
        </div>
    );
}

function PickRow({
    label,
    value,
    selected,
    onClick,
    onCopy,
}: {
    label: string;
    value: any;
    selected: boolean;
    onClick: () => void;
    onCopy?: () => void;
}) {
    return (
        <label
            onClick={onClick}
            className={
                "flex items-start gap-2 cursor-pointer px-1.5 py-1 rounded transition-colors " +
                (selected ? "bg-blue-50" : "hover:bg-white")
            }
        >
            <input
                type="radio"
                checked={selected}
                onChange={onClick}
                className="mt-0.5"
            />
            <span className="text-[10px] text-gray-500 shrink-0 mt-0.5 w-14">
                {label}
            </span>
            <span className="text-xs font-mono text-gray-800 truncate flex-1">
                {formatValue(value)}
            </span>
            {onCopy && (
                <button
                    type="button"
                    onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        onCopy();
                    }}
                    title="Copy to Custom"
                    className="shrink-0 text-gray-400 hover:text-blue-600 p-0.5 rounded"
                >
                    <Copy className="h-3 w-3" />
                </button>
            )}
        </label>
    );
}

function formatValue(v: any): string {
    if (v === null) return "null";
    if (v === undefined) return "—";
    if (typeof v === "string") return v.length > 0 ? v : "(empty string)";
    return String(v);
}

// parseCustom does best-effort type coercion on a raw text input.
// Numbers stay numbers, "true"/"false" become bool, empty becomes null.
function parseCustom(raw: string): any {
    const trimmed = raw.trim();
    if (trimmed === "") return null;
    if (trimmed === "true") return true;
    if (trimmed === "false") return false;
    if (trimmed === "null") return null;
    const asNum = Number(trimmed);
    if (!Number.isNaN(asNum) && /^-?\d+(\.\d+)?$/.test(trimmed)) {
        return asNum;
    }
    return trimmed; // keep as string
}