import { Plus, Trash2 } from "lucide-react";

interface Choice {
  value: string;
  label: { en: string };
}

interface Props {
  choices: Choice[];
  onChange: (choices: Choice[]) => void;
}

export function ChoiceEditor({ choices, onChange }: Props) {
  const addChoice = () => {
    const num = choices.length + 1;
    onChange([
      ...choices,
      {
        value: "option_" + num,
        label: { en: "Option " + num },
      },
    ]);
  };

  const updateChoice = (
    index: number,
    field: "value" | "label",
    val: string
  ) => {
    const updated = [...choices];
    if (field === "value") {
      updated[index] = { ...updated[index], value: val };
    } else {
      updated[index] = { ...updated[index], label: { en: val } };
    }
    onChange(updated);
  };

  const removeChoice = (index: number) => {
    onChange(choices.filter((_, i) => i !== index));
  };

  return (
    <div className="flex flex-col gap-2">
      <label className="text-xs font-medium text-gray-600">Choices</label>
      {choices.map((choice, i) => (
        <div key={i} className="flex items-center gap-2">
          <input
            value={choice.value}
            onChange={(e) => updateChoice(i, "value", e.target.value)}
            placeholder="Value"
            className="w-1/3 rounded border border-gray-300 px-2 py-1 text-xs font-mono"
          />
          <input
            value={choice.label.en}
            onChange={(e) => updateChoice(i, "label", e.target.value)}
            placeholder="Label"
            className="flex-1 rounded border border-gray-300 px-2 py-1 text-xs"
          />
          <button
            onClick={() => removeChoice(i)}
            className="text-gray-400 hover:text-red-500"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        </div>
      ))}
      <button
        type="button"
        onClick={addChoice}
        className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800 mt-1"
      >
        <Plus className="h-3 w-3" /> Add choice
      </button>
    </div>
  );
}