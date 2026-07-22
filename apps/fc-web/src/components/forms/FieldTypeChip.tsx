interface Props {
    type: string;
  }
  
  const TYPE_STYLES: Record<string, { bg: string; fg: string; label?: string }> = {
    text: { bg: "bg-blue-50", fg: "text-blue-700" },
    text_area: { bg: "bg-blue-50", fg: "text-blue-700", label: "text" },
    integer: { bg: "bg-purple-50", fg: "text-purple-700" },
    decimal: { bg: "bg-purple-50", fg: "text-purple-700" },
    number: { bg: "bg-purple-50", fg: "text-purple-700" },
    boolean: { bg: "bg-orange-50", fg: "text-orange-700" },
    select_one: { bg: "bg-emerald-50", fg: "text-emerald-700" },
    select_multiple: { bg: "bg-emerald-50", fg: "text-emerald-700" },
    date: { bg: "bg-indigo-50", fg: "text-indigo-700" },
    datetime: { bg: "bg-indigo-50", fg: "text-indigo-700" },
    time: { bg: "bg-indigo-50", fg: "text-indigo-700" },
    photo: { bg: "bg-pink-50", fg: "text-pink-700" },
    image: { bg: "bg-pink-50", fg: "text-pink-700", label: "photo" },
    signature: { bg: "bg-pink-50", fg: "text-pink-700" },
    geopoint: { bg: "bg-teal-50", fg: "text-teal-700" },
    line: { bg: "bg-teal-50", fg: "text-teal-700" },
    polygon: { bg: "bg-teal-50", fg: "text-teal-700" },
    note: { bg: "bg-gray-100", fg: "text-gray-600" },
  };
  
  const DEFAULT_STYLE = { bg: "bg-gray-100", fg: "text-gray-500" };
  
  export function FieldTypeChip({ type }: Props) {
    const style = TYPE_STYLES[type] ?? DEFAULT_STYLE;
    return (
      <span
        className={`rounded px-1.5 py-0.5 text-[11px] font-mono ${style.bg} ${style.fg}`}
      >
        {style.label ?? type}
      </span>
    );
  }