import { create } from "zustand";
import type { Selection } from "./store";

export interface PickerCandidate extends Selection {
  label: string;
}

export interface PickerMenuAnchor {
  x: number;
  y: number;
  candidates: PickerCandidate[];
}

interface PickerState {
  menu: PickerMenuAnchor | null;
  openMenu: (anchor: PickerMenuAnchor) => void;
  closeMenu: () => void;
}

export const usePickerStore = create<PickerState>((set) => ({
  menu: null,
  openMenu: (anchor) => set({ menu: anchor }),
  closeMenu: () => set({ menu: null }),
}));
