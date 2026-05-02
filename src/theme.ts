import type { AppSettings } from "./types/hopdeck";

type TerminalColors = AppSettings["terminal"]["colors"];
type Appearance = AppSettings["theme"];

export const darkTerminalColors: TerminalColors = {
  background: "#0F1720",
  foreground: "#DBE7F3",
  cursor: "#41B6C8",
  selection: "#24384A",
  ansi: [
    "#172331",
    "#EF8A80",
    "#7FD19B",
    "#E5C15D",
    "#69A7E8",
    "#B99CFF",
    "#41B6C8",
    "#DBE7F3",
    "#8EA0B4",
    "#FFB8B0",
    "#A6E3B6",
    "#F4D675",
    "#9BC7FF",
    "#CFB8FF",
    "#75D7E4",
    "#F3F7FB"
  ]
};

export const lightTerminalColors: TerminalColors = {
  background: "#F7FAFC",
  foreground: "#243447",
  cursor: "#168AA0",
  selection: "#CFE8F0",
  ansi: [
    "#243447",
    "#B94A48",
    "#2E8B57",
    "#A96F00",
    "#2374AB",
    "#7D5FB2",
    "#168AA0",
    "#EEF4F8",
    "#6B7D8F",
    "#D7605A",
    "#3EA66B",
    "#C98A17",
    "#3B8EDB",
    "#9272CF",
    "#27A8BC",
    "#FFFFFF"
  ]
};

export const terminalColorsForAppearance = (appearance: Exclude<Appearance, "system">): TerminalColors =>
  appearance === "light" ? lightTerminalColors : darkTerminalColors;

export const terminalBackgroundAlpha = (backgroundOpacity: number, backgroundBlur: number): number => {
  const alpha = clamp(backgroundOpacity / 100, 0.15, 1);

  if (backgroundBlur <= 0) {
    return alpha;
  }

  return Math.min(alpha, 0.9);
};

export const terminalBackgroundColor = (hex: string, backgroundOpacity: number, backgroundBlur: number): string =>
  hexToRgba(hex, terminalBackgroundAlpha(backgroundOpacity, backgroundBlur));

export const isBuiltInTerminalColors = (colors: TerminalColors): boolean =>
  areTerminalColorsEqual(colors, darkTerminalColors) || areTerminalColorsEqual(colors, lightTerminalColors);

const hexToRgba = (hex: string, alpha: number): string => {
  const normalized = hex.trim().replace("#", "");
  const value =
    normalized.length === 3
      ? normalized
          .split("")
          .map((digit) => digit + digit)
          .join("")
      : normalized;

  if (!/^[0-9a-fA-F]{6}$/.test(value)) {
    return `rgba(15, 23, 32, ${clamp(alpha, 0, 1)})`;
  }

  const red = Number.parseInt(value.slice(0, 2), 16);
  const green = Number.parseInt(value.slice(2, 4), 16);
  const blue = Number.parseInt(value.slice(4, 6), 16);
  return `rgba(${red}, ${green}, ${blue}, ${clamp(alpha, 0, 1)})`;
};

const clamp = (value: number, min: number, max: number): number => Math.min(Math.max(value, min), max);

const areTerminalColorsEqual = (left: TerminalColors, right: TerminalColors): boolean =>
  left.background === right.background &&
  left.foreground === right.foreground &&
  left.cursor === right.cursor &&
  left.selection === right.selection &&
  left.ansi.length === right.ansi.length &&
  left.ansi.every((color, index) => color === right.ansi[index]);
