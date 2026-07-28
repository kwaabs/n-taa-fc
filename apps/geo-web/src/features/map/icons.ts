// Central registry of SDF-style symbol SVGs.
// Used by both the map sprite loader and the sidebar legend.
// Source of truth: shared/map-symbols/*.svg (same files embedded in fc-api).

import arresterSvg from "@map-symbols/arrester.svg?raw";
import batterySvg from "@map-symbols/battery.svg?raw";
import breakerSvg from "@map-symbols/breaker.svg?raw";
import buildingSvg from "@map-symbols/building.svg?raw";
import busbarSvg from "@map-symbols/busbar.svg?raw";
import capacitorSvg from "@map-symbols/capacitor.svg?raw";
import ctSvg from "@map-symbols/ct.svg?raw";
import dotSvg from "@map-symbols/dot.svg?raw";
import earthSvg from "@map-symbols/earth.svg?raw";
import isolatorSvg from "@map-symbols/isolator.svg?raw";
import lbsSvg from "@map-symbols/lbs.svg?raw";
import meterSvg from "@map-symbols/meter.svg?raw";
import panelSvg from "@map-symbols/panel.svg?raw";
import poleSvg from "@map-symbols/pole.svg?raw";
import recloserSvg from "@map-symbols/recloser.svg?raw";
import relaySvg from "@map-symbols/relay.svg?raw";
import scadaSvg from "@map-symbols/scada.svg?raw";
import sectionalizerSvg from "@map-symbols/sectionalizer.svg?raw";
import switchgearSvg from "@map-symbols/switchgear.svg?raw";
import transformerSvg from "@map-symbols/transformer.svg?raw";
import vtSvg from "@map-symbols/vt.svg?raw";

export const ICONS: Record<string, string> = {
  dot: dotSvg,
  arrester: arresterSvg,
  breaker: breakerSvg,
  isolator: isolatorSvg,
  lbs: lbsSvg,
  sectionalizer: sectionalizerSvg,
  recloser: recloserSvg,
  switchgear: switchgearSvg,
  transformer: transformerSvg,
  ct: ctSvg,
  vt: vtSvg,
  meter: meterSvg,
  capacitor: capacitorSvg,
  busbar: busbarSvg,
  pole: poleSvg,
  panel: panelSvg,
  building: buildingSvg,
  battery: batterySvg,
  earth: earthSvg,
  scada: scadaSvg,
  relay: relaySvg,
};

/**
 * Prepare an SVG for inline React rendering:
 *  - Strips width/height so the container controls size.
 *  - Rewrites black fills/strokes to `currentColor` so a wrapping
 *    element can tint via `style={{ color }}`.
 */
export function inlineTintedSvg(name: string): string | null {
  const raw = ICONS[name];
  if (!raw) return null;
  return raw
    .replace(
      /<svg([^>]*)>/,
      (_, attrs) =>
        `<svg${attrs
          .replace(/\swidth="[^"]*"/gi, "")
          .replace(/\sheight="[^"]*"/gi, "")}>`,
    )
    .replace(/fill="(black|#000|#000000)"/gi, 'fill="currentColor"')
    .replace(/stroke="(black|#000|#000000)"/gi, 'stroke="currentColor"');
}
