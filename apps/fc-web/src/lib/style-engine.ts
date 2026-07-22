// Mirror of the backend style spec types.

export interface StyleProps {
    icon?: string;
    color?: string;
    size?: number;
    stroke_color?: string;
    stroke_width?: number;
    opacity?: number;
    stroke_opacity?: number;
    line_style?: string;
    icon_svg?: string;
  }

  
  export interface RuleClause {
    field?: string;
    op?: string;
    value?: any;
    and?: RuleClause[];
    or?: RuleClause[];
  }
  
  export interface StyleRule {
    id: string;
    name?: string;
    when: RuleClause;
    style: StyleProps;
  }
  
  export interface LabelSpec {
    field: string;
    color?: string;
    halo_color?: string;
    halo_width?: number;
    size?: number;
    min_zoom?: number;
    max_zoom?: number;
  }
  
  export interface Visibility {
    min_zoom?: number;
    max_zoom?: number;
    visible_by_default?: boolean;
  }
  
  export interface LayerStyle {
    default: StyleProps;
    rules?: StyleRule[];
    label?: LabelSpec;
    visibility?: Visibility;
  }
  
  // ── Evaluator ────────────────────────────────────────────
  
  function getFieldValue(attrs: any, field: string): any {
    if (!attrs) return undefined;
    return attrs[field];
  }
  
  function compare(left: any, op: string, right: any): boolean {
    if (op === "is_null") return left === null || left === undefined;
    if (op === "is_not_null") return left !== null && left !== undefined;
  
    if (left === undefined || left === null) return false;
  
    switch (op) {
      case "eq":  return String(left) === String(right);
      case "neq": return String(left) !== String(right);
      case "gt":  return Number(left) > Number(right);
      case "lt":  return Number(left) < Number(right);
      case "gte": return Number(left) >= Number(right);
      case "lte": return Number(left) <= Number(right);
      case "in":
        return Array.isArray(right) && right.some((v) => String(v) === String(left));
      case "not_in":
        return Array.isArray(right) && !right.some((v) => String(v) === String(left));
      case "contains":
        return String(left).toLowerCase().includes(String(right).toLowerCase());
      default:
        return false;
    }
  }
  
  export function evaluateClause(clause: RuleClause, attrs: any): boolean {
    if (clause.and && clause.and.length > 0) {
      return clause.and.every((c) => evaluateClause(c, attrs));
    }
    if (clause.or && clause.or.length > 0) {
      return clause.or.some((c) => evaluateClause(c, attrs));
    }
    if (clause.field && clause.op) {
      const fv = getFieldValue(attrs, clause.field);
      return compare(fv, clause.op, clause.value);
    }
    return false;
  }
  
  // Compute the effective style for a feature: default + all matching rules merged in order.
  export function computeFeatureStyle(style: LayerStyle | null | undefined, attrs: any): StyleProps {
    if (!style) {
      return { color: "#3b82f6", size: 12, stroke_color: "#ffffff", stroke_width: 2 };
    }
    let merged: StyleProps = { ...style.default };
    for (const rule of style.rules || []) {
      if (evaluateClause(rule.when, attrs)) {
        merged = { ...merged, ...rule.style };
      }
    }
    return merged;
  }
  
  // Get the label value for a feature (or null).
  export function getLabelText(style: LayerStyle | null | undefined, attrs: any): string | null {
    if (!style?.label?.field || !attrs) return null;
    const v = attrs[style.label.field];
    return v == null ? null : String(v);
  }
  
  export function isVisibleByDefault(style: LayerStyle | null | undefined): boolean {
    if (!style?.visibility) return true;
    return style.visibility.visible_by_default !== false;
  }