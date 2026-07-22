import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Plus, ListTree, ChevronRight } from "lucide-react";

import { ChoiceListDrawer } from "@/components/choice-lists/ChoiceListDrawer";

export function ChoiceListsPage() {
  const { projectId } = useParams();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editingList, setEditingList] = useState<any | null>(null);

  const { data: lists, isLoading } = useQuery({
    queryKey: ["choiceLists", projectId],
    queryFn: () => api.getProjectChoiceLists(projectId!),
    enabled: !!projectId,
  });

  const openCreate = () => {
    setEditingList(null);
    setDrawerOpen(true);
  };

  const openEdit = (list: any) => {
    setEditingList(list);
    setDrawerOpen(true);
  };

  const closeDrawer = () => {
    setDrawerOpen(false);
    setEditingList(null);
  };

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Choice Lists</h2>
          <p className="text-xs text-gray-500 mt-0.5">
            Reusable lists of options attached to form fields.
          </p>
        </div>
        <button
          onClick={openCreate}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Plus className="h-4 w-4" /> New Choice List
        </button>
      </div>

      {isLoading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          {lists?.length === 0 ? (
            <div className="flex flex-col items-center justify-center text-center py-12">
              <div className="rounded-full bg-gray-50 p-3 mb-3">
                <ListTree className="h-6 w-6 text-gray-400" />
              </div>
              <h3 className="text-base font-medium text-gray-900">
                No choice lists yet
              </h3>
              <p className="text-sm text-gray-500 mt-1 max-w-md">
                Create a choice list to reuse the same options across multiple
                form fields.
              </p>
              <button
                onClick={openCreate}
                className="mt-4 flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-700"
              >
                <Plus className="h-4 w-4" /> Create your first list
              </button>
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">
                    Name
                  </th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">
                    Choices
                  </th>
                  <th className="text-left px-4 py-3 font-medium text-gray-600">
                    Updated
                  </th>
                  <th className="w-10 px-2 py-3"></th>
                </tr>
              </thead>
              <tbody>
                {(lists ?? []).map((cl: any) => {
                  const choiceArr = Array.isArray(cl.choices) ? cl.choices : [];
                  return (
                    <tr
                      key={cl.id}
                      onClick={() => openEdit(cl)}
                      className="border-b border-gray-100 cursor-pointer hover:bg-blue-50/40"
                    >
                      <td className="px-4 py-3 font-medium text-gray-900">
                        {cl.name}
                      </td>
                      <td className="px-4 py-3 text-gray-600">
                        {choiceArr.length} option
                        {choiceArr.length === 1 ? "" : "s"}
                      </td>
                      <td className="px-4 py-3 text-gray-500">
                        {cl.updated_at
                          ? new Date(cl.updated_at).toLocaleDateString()
                          : "—"}
                      </td>
                      <td className="px-2 py-3 text-right">
                        <ChevronRight className="h-4 w-4 text-gray-300 inline" />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>
      )}

      <ChoiceListDrawer
        projectId={projectId!}
        list={editingList}
        open={drawerOpen}
        onClose={closeDrawer}
      />
    </div>
  );
}