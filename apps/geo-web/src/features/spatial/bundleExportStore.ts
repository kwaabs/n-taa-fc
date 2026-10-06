import { create } from "zustand";

interface BundleExportState {
  open: boolean;
  openDialog: () => void;
  closeDialog: () => void;
}

export const useBundleExportStore = create<BundleExportState>((set) => ({
  open: false,
  openDialog: () => set({ open: true }),
  closeDialog: () => set({ open: false }),
}));
