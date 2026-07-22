import { useState } from "react";
import { useParams } from "react-router-dom";
import { Megaphone } from "lucide-react";
import { SendMessageDialog } from "@/components/messages/SendMessageDialog";

export function ProjectMessagesPage() {
  const { projectId } = useParams();
  const [showSend, setShowSend] = useState(false);

  if (!projectId) return null;

  return (
    <div className="flex flex-col h-full max-w-2xl">
      <div className="flex items-center justify-between mb-4 shrink-0">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Messages</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            One-way notices to a project team or an individual field worker.
          </p>
        </div>
        <button
          onClick={() => setShowSend(true)}
          className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <Megaphone className="h-4 w-4" /> Send message
        </button>
      </div>

      <div className="rounded-xl border border-dashed border-gray-200 bg-gray-50 px-6 py-10 text-center text-gray-500">
        <Megaphone className="h-10 w-10 mx-auto mb-3 text-gray-400" />
        <p className="font-medium text-gray-700">Send a notice to the field</p>
        <p className="text-sm mt-1 max-w-md mx-auto">
          Recipients see it in the mobile notification bell the next time they open
          the app online. No sync or bundle download required. No replies.
        </p>
      </div>

      {showSend && (
        <SendMessageDialog
          projectId={projectId}
          onClose={() => setShowSend(false)}
        />
      )}
    </div>
  );
}
