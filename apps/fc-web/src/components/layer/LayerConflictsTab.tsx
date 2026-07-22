import { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
    AlertCircle,
    CheckCircle2,
    Database,
    Loader2,
    ChevronRight,
    Trash2,
    Edit3,
    Wrench,
    StickyNote,
} from "lucide-react";
import { ManualMergeEditor } from "./ManualMergeEditor";
import { api } from "@/lib/api";
import { ConflictDiffView } from "./ConflictDiffView";

interface Props {
    projectId: string;
    layerId: string;
}

export function LayerConflictsTab({ projectId, layerId }: Props) {
    const queryClient = useQueryClient();
    const [selectedId, setSelectedId] = useState<string | null>(null);
    const [notes, setNotes] = useState("");
    const [manualMode, setManualMode] = useState(false);

    const { data, isLoading, error } = useQuery({
        queryKey: ["reconcileConflicts", layerId],
        queryFn: () => api.listReconciliationConflicts(projectId, layerId),
        enabled: !!layerId,
    });

    const conflicts = useMemo(() => data?.conflicts ?? [], [data]);
    const selected = conflicts.find((c: any) => c.id === selectedId) ?? conflicts[0];

    const resolveMutation = useMutation({
        mutationFn: async (input: {
            resolution: "field_wins" | "source_wins" | "manual";
            mergedAttrs?: Record<string, any>;
        }) => {
            if (!selected) throw new Error("no conflict selected");
            const body: any = { resolution: input.resolution, notes };
            if (input.resolution === "field_wins") {
                body.resolved_attrs = selected.field_attrs ?? selected.original_attrs ?? {};
            } else if (input.resolution === "source_wins") {
                body.resolved_attrs = selected.source_attrs ?? {};
            } else if (input.resolution === "manual") {
                body.resolved_attrs = input.mergedAttrs ?? {};
            }
            return api.resolveReconciliationConflict(projectId, selected.id, body);
        },
        onSuccess: (_data, variables) => {
            queryClient.invalidateQueries({ queryKey: ["reconcileConflicts", layerId] });
            const action =
                variables.resolution === "field_wins"
                    ? "applied at next Apply"
                    : variables.resolution === "source_wins"
                        ? "kept as-is (deletion cancelled)"
                        : "merged at next Apply";
            toast.success("Resolution recorded", {
                description: `Source DB will be ${action}. Run Apply on Data Sources to commit.`,
            });
            setNotes("");
            setManualMode(false);
            setSelectedId(null);
        },
        onError: (err: any) => {
            toast.error("Resolution failed", {
                description: err?.message ?? "Could not resolve conflict.",
            });
        },
    });

    if (isLoading) {
        return (
            <div className="flex items-center justify-center py-12">
                <Loader2 className="h-6 w-6 text-gray-400 animate-spin" />
            </div>
        );
    }

    if (error) {
        return (
            <div className="rounded-lg border border-red-200 bg-red-50 p-4">
                <p className="text-sm text-red-700">
                    Failed to load conflicts: {(error as Error).message}
                </p>
            </div>
        );
    }

    if (conflicts.length === 0) {
        return (
            <div className="bg-white rounded-xl border border-dashed border-gray-300 p-12 text-center">
                <CheckCircle2 className="h-12 w-12 mx-auto text-green-300 mb-3" />
                <h3 className="text-base font-medium text-gray-900">No pending conflicts</h3>
                <p className="text-sm text-gray-500 mt-1 max-w-md mx-auto">
                    Run Preview from the Data Sources tab to detect new conflicts. Resolved
                    conflicts are not shown here.
                </p>
            </div>
        );
    }

    return (
        <div className="flex flex-col gap-3">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-lg font-semibold text-gray-900">Conflicts</h2>
                    <p className="text-sm text-gray-500 mt-0.5">
                        {conflicts.length} pending — resolve each before the next Apply run.
                    </p>

                </div>
            </div>

            {/* Master-detail */}
            <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-3">
                {/* List */}
                <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
                    <ul className="divide-y divide-gray-100 max-h-[600px] overflow-y-auto">
                        {conflicts.map((c: any) => (
                            <li key={c.id}>
                                <button
                                    onClick={() => setSelectedId(c.id)}
                                    className={
                                        "w-full text-left px-3 py-2.5 transition-colors flex items-start gap-2 " +
                                        (selected?.id === c.id
                                            ? "bg-blue-50"
                                            : "hover:bg-gray-50")
                                    }
                                >
                                    <div className="pt-0.5">
                                        {c.change_type === "deleted" ? (
                                            <Trash2 className="h-3.5 w-3.5 text-red-500" />
                                        ) : (
                                            <Edit3 className="h-3.5 w-3.5 text-blue-500" />
                                        )}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <p className="text-xs font-mono text-gray-700 truncate">
                                            {c.source_ref}
                                        </p>
                                        <p className="text-[10px] text-gray-500 mt-0.5">
                                            {c.change_type} ·{" "}
                                            {(c.conflicting_fields ?? []).length} fields
                                        </p>
                                    </div>
                                    <ChevronRight className="h-3.5 w-3.5 text-gray-300 shrink-0 mt-1" />
                                </button>
                            </li>
                        ))}
                    </ul>
                </div>

                {/* Detail */}
                <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-col gap-4">
                    {selected ? (
                        <>
                            {/* Detail header */}
                            <div className="flex items-start gap-3 pb-3 border-b border-gray-200">
                                <div className="rounded-lg bg-amber-50 p-2 shrink-0">
                                    <AlertCircle className="h-5 w-5 text-amber-600" />
                                </div>
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-2 flex-wrap">
                                        <h3 className="font-semibold text-gray-900 truncate">
                                            {selected.source_ref}
                                        </h3>
                                        <span
                                            className={
                                                "rounded-full px-2 py-0.5 text-[10px] font-medium " +
                                                (selected.change_type === "deleted"
                                                    ? "bg-red-50 text-red-700"
                                                    : "bg-blue-50 text-blue-700")
                                            }
                                        >
                                            {selected.change_type}
                                        </span>
                                    </div>
                                    <p className="text-xs text-gray-500 mt-0.5">
                                        {selected.conflicting_fields?.length ?? 0} conflicting field
                                        {selected.conflicting_fields?.length === 1 ? "" : "s"}:{" "}
                                        <span className="font-mono">
                                            {(selected.conflicting_fields ?? []).join(", ") || "—"}
                                        </span>
                                    </p>

                                </div>
                            </div>

                            {/* Diff */}
                            <ConflictDiffView conflict={selected} />

                            {/* Notes */}
                            <div className="border-t border-gray-200 pt-3">
                                <label className="flex items-center gap-1.5 text-xs font-medium text-gray-700 mb-1">
                                    <StickyNote className="h-3.5 w-3.5" />
                                    Notes (optional)
                                </label>
                                <textarea
                                    value={notes}
                                    onChange={(e) => setNotes(e.target.value)}
                                    placeholder="Why this resolution?"
                                    rows={2}
                                    className="w-full rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs resize-none"
                                />
                            </div>

                            {/* Resolution actions */}
                            {manualMode ? (
                                <ManualMergeEditor
                                    conflict={selected}
                                    saving={resolveMutation.isPending}
                                    onCancel={() => setManualMode(false)}
                                    onSave={(merged) =>
                                        resolveMutation.mutate({ resolution: "manual", mergedAttrs: merged })
                                    }
                                />
                            ) : (
                                <div className="flex flex-col gap-2 border-t border-gray-200 pt-3">
                                    <p className="text-xs text-gray-500">
                                        Pick a resolution. The next Apply run will honor it.
                                    </p>
                                    <div className="grid grid-cols-3 gap-2">
                                        <button
                                            onClick={() => resolveMutation.mutate({ resolution: "field_wins" })}
                                            disabled={resolveMutation.isPending}
                                            title={
                                                selected.change_type === "deleted"
                                                    ? "Honor the surveyor's deletion — delete the row anyway"
                                                    : "Use the field-collected edit (overwrites source's recent changes)"
                                            }
                                            className="flex items-center justify-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed"
                                        >
                                            <Edit3 className="h-3.5 w-3.5" />
                                            Field wins
                                        </button>
                                        <button
                                            onClick={() => resolveMutation.mutate({ resolution: "source_wins" })}
                                            disabled={resolveMutation.isPending}
                                            title="Keep source DB as-is (dismiss the change)"
                                            className="flex items-center justify-center gap-1.5 rounded-lg bg-gray-600 px-3 py-2 text-xs font-medium text-white hover:bg-gray-700 disabled:opacity-40"
                                        >
                                            <Database className="h-3.5 w-3.5" />
                                            Source wins
                                        </button>
                                        <button
                                            onClick={() => setManualMode(true)}
                                            disabled={resolveMutation.isPending}
                                            title="Merge field-by-field — pick Source / Surveyor / Original / Custom for each"
                                            className="flex items-center justify-center gap-1.5 rounded-lg border border-gray-300 px-3 py-2 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-40"
                                        >
                                            <Wrench className="h-3.5 w-3.5" />
                                            Manual
                                        </button>
                                    </div>
                                </div>
                            )}
                        </>
                    ) : (
                        <p className="text-sm text-gray-400 italic text-center py-12">
                            Select a conflict to review
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
}