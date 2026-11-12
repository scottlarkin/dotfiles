// Vim-style modal prompt editor for pi.
//
// Motions and operators run against the editor's text directly (vim word
// semantics, counts, text objects), rather than being translated into pi's
// emacs-style keys, which don't match vim (alt+f stops at word end, alt+d
// eats the leading space).
//
// pi's Editor exposes getLines/getCursor but no setCursor, and setText() drops
// paste markers, so edits use a few non-public Editor members via `internals()`.
// If a pi upgrade renames them, normal mode is disabled and the editor falls
// back to plain insert behaviour instead of crashing.

import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

interface EditorInternals {
  state: { lines: string[]; cursorLine: number; cursorCol: number };
  setCursorCol(col: number): void;
  pushUndoSnapshot(): void;
  undo(): void;
  onChange?: (text: string) => void;
}

type Mode = "normal" | "insert";
type Register = { text: string; linewise: boolean };
type Range = { start: number; end: number; linewise: boolean };
type Motion = { to: number; inclusive: boolean; linewise?: boolean };
type FindCommand = { kind: "f" | "F" | "t" | "T"; char: string };

const KEY_UP = "\x1b[A";
const KEY_DOWN = "\x1b[B";
const OPERATORS = new Set(["d", "c", "y"]);
const BRACKETS: Record<string, [string, string]> = {
  "(": ["(", ")"], ")": ["(", ")"], b: ["(", ")"],
  "[": ["[", "]"], "]": ["[", "]"],
  "{": ["{", "}"], "}": ["{", "}"], B: ["{", "}"],
  "<": ["<", ">"], ">": ["<", ">"],
};
const QUOTES = new Set(['"', "'", "`"]);

/** Character class for vim word motions: 0 blank, 1 keyword, 2 punctuation. */
function charClass(ch: string | undefined, bigWord: boolean): number {
  if (ch === undefined || /\s/.test(ch)) return 0;
  if (bigWord) return 1;
  return /\w/.test(ch) ? 1 : 2;
}

/** Start of the next word (vim `w`/`W`). */
function wordForward(s: string, p: number, big: boolean): number {
  const c = charClass(s[p], big);
  if (c !== 0) while (p < s.length && charClass(s[p], big) === c) p++;
  while (p < s.length && charClass(s[p], big) === 0) p++;
  return p;
}

/** End of the current or next word (vim `e`/`E`). */
function wordEnd(s: string, p: number, big: boolean): number {
  p++;
  while (p < s.length && charClass(s[p], big) === 0) p++;
  if (p >= s.length) return Math.max(s.length - 1, 0);
  const c = charClass(s[p], big);
  while (p + 1 < s.length && charClass(s[p + 1], big) === c) p++;
  return p;
}

/** Start of the current or previous word (vim `b`/`B`). */
function wordBack(s: string, p: number, big: boolean): number {
  p--;
  while (p > 0 && charClass(s[p], big) === 0) p--;
  if (p <= 0) return 0;
  const c = charClass(s[p], big);
  while (p > 0 && charClass(s[p - 1], big) === c) p--;
  return p;
}

function lineStart(s: string, p: number): number {
  return s.lastIndexOf("\n", p - 1) + 1;
}

function lineEnd(s: string, p: number): number {
  const i = s.indexOf("\n", p);
  return i === -1 ? s.length : i;
}

/** Target of f/F/t/T on the current line, or undefined if the char isn't found. */
function findOnLine(s: string, p: number, { kind, char }: FindCommand): number | undefined {
  const start = lineStart(s, p);
  const end = lineEnd(s, p);
  if (kind === "f" || kind === "t") {
    const i = s.indexOf(char, p + 1);
    if (i === -1 || i >= end) return undefined;
    return kind === "f" ? i : i - 1;
  }
  const i = s.lastIndexOf(char, p - 1);
  if (i < start) return undefined;
  return kind === "F" ? i : i + 1;
}

/** Range of a text object (iw, aw, i", a(, ...) around p. */
function textObject(s: string, p: number, scope: "i" | "a", obj: string): Range | undefined {
  if (obj === "w" || obj === "W") {
    const big = obj === "W";
    const c = charClass(s[p], big);
    let start = p;
    let end = p;
    while (start > 0 && charClass(s[start - 1], big) === c && s[start - 1] !== "\n") start--;
    while (end < s.length && charClass(s[end], big) === c && s[end] !== "\n") end++;
    if (scope === "a") {
      const trailing = end;
      while (end < s.length && s[end] !== "\n" && /\s/.test(s[end]!)) end++;
      if (end === trailing) while (start > 0 && s[start - 1] !== "\n" && /\s/.test(s[start - 1]!)) start--;
    }
    return { start, end, linewise: false };
  }
  if (QUOTES.has(obj)) {
    const ls = lineStart(s, p);
    const le = lineEnd(s, p);
    const open = s[p] === obj ? p : s.lastIndexOf(obj, p - 1);
    if (open < ls) return undefined;
    const close = s.indexOf(obj, open + 1);
    if (close === -1 || close >= le) return undefined;
    return scope === "i"
      ? { start: open + 1, end: close, linewise: false }
      : { start: open, end: close + 1, linewise: false };
  }
  const pair = BRACKETS[obj];
  if (!pair) return undefined;
  const [o, c] = pair;
  let depth = 0;
  let open = -1;
  for (let i = s[p] === c ? p - 1 : p; i >= 0; i--) {
    if (s[i] === c) depth++;
    else if (s[i] === o) {
      if (depth === 0) {
        open = i;
        break;
      }
      depth--;
    }
  }
  if (open === -1) return undefined;
  depth = 0;
  for (let i = open + 1; i < s.length; i++) {
    if (s[i] === o) depth++;
    else if (s[i] === c) {
      if (depth === 0) {
        return scope === "i"
          ? { start: open + 1, end: i, linewise: false }
          : { start: open, end: i + 1, linewise: false };
      }
      depth--;
    }
  }
  return undefined;
}

class VimEditor extends CustomEditor {
  private mode: Mode = "insert";
  private pending = "";
  private register: Register = { text: "", linewise: false };
  private lastFind: FindCommand | undefined;

  private internals(): EditorInternals | undefined {
    const e = this as unknown as Partial<EditorInternals>;
    const ok =
      e.state && Array.isArray(e.state.lines) && typeof e.setCursorCol === "function" &&
      typeof e.pushUndoSnapshot === "function" && typeof e.undo === "function";
    return ok ? (e as EditorInternals) : undefined;
  }

  handleInput(data: string): void {
    const ed = this.internals();
    if (!ed) {
      super.handleInput(data);
      return;
    }

    if (matchesKey(data, "escape")) {
      if (this.mode === "insert") {
        this.mode = "normal";
        if (ed.state.cursorCol > 0) ed.setCursorCol(ed.state.cursorCol - 1);
      } else if (this.pending) {
        this.pending = "";
      } else {
        super.handleInput(data); // keep pi's meaning (abort) in normal mode
      }
      return;
    }

    if (this.mode === "insert") {
      super.handleInput(data);
      return;
    }

    // Control sequences (enter, ctrl+c, arrows, shortcuts) keep their pi meaning.
    if (data.length !== 1 || data.charCodeAt(0) < 32) {
      this.pending = "";
      super.handleInput(data);
      return;
    }

    this.pending += data;
    if (this.execute(ed, this.pending) !== "incomplete") this.pending = "";
  }

  // --- buffer helpers -------------------------------------------------------

  private text(ed: EditorInternals): string {
    return ed.state.lines.join("\n");
  }

  private offset(ed: EditorInternals): number {
    const { lines, cursorLine, cursorCol } = ed.state;
    let o = 0;
    for (let i = 0; i < cursorLine; i++) o += lines[i]!.length + 1;
    return o + cursorCol;
  }

  private moveTo(ed: EditorInternals, offset: number, clampToChar = true): void {
    const lines = ed.state.lines;
    let line = 0;
    let rest = Math.max(0, offset);
    while (line < lines.length - 1 && rest > lines[line]!.length) {
      rest -= lines[line]!.length + 1;
      line++;
    }
    const len = lines[line]!.length;
    const max = clampToChar ? Math.max(len - 1, 0) : len;
    ed.state.cursorLine = line;
    ed.setCursorCol(Math.min(rest, max));
  }

  private replaceText(ed: EditorInternals, next: string, cursor: number, clampToChar: boolean): void {
    if (next !== this.text(ed)) ed.pushUndoSnapshot();
    ed.state.lines = next.split("\n");
    this.moveTo(ed, cursor, clampToChar);
    ed.onChange?.(next);
  }

  private deleteRange(ed: EditorInternals, range: Range, intoInsert: boolean): void {
    const s = this.text(ed);
    let { start, end } = range;
    if (range.linewise) {
      start = lineStart(s, start);
      end = lineEnd(s, Math.max(end - 1, start));
      this.register = { text: s.slice(start, end), linewise: true };
      if (intoInsert) {
        this.replaceText(ed, s.slice(0, start) + s.slice(end), start, false);
        return;
      }
      // Remove the line break too: the following one, or the preceding one on the last line.
      if (end < s.length) end++;
      else if (start > 0) start--;
      const next = s.slice(0, start) + s.slice(end);
      this.replaceText(ed, next, start === 0 ? 0 : lineStart(next, Math.min(start + 1, next.length)), true);
      return;
    }
    this.register = { text: s.slice(start, end), linewise: false };
    this.replaceText(ed, s.slice(0, start) + s.slice(end), start, !intoInsert);
  }

  private yankRange(ed: EditorInternals, range: Range): void {
    const s = this.text(ed);
    if (range.linewise) {
      const start = lineStart(s, range.start);
      const end = lineEnd(s, Math.max(range.end - 1, start));
      this.register = { text: s.slice(start, end), linewise: true };
      this.moveTo(ed, start);
      return;
    }
    this.register = { text: s.slice(range.start, range.end), linewise: false };
    this.moveTo(ed, range.start);
  }

  private put(ed: EditorInternals, before: boolean, count: number): void {
    const s = this.text(ed);
    const p = this.offset(ed);
    const { text, linewise } = this.register;
    if (!text && !linewise) return;
    const body = Array(count).fill(text).join(linewise ? "\n" : "");
    if (linewise) {
      const at = before ? lineStart(s, p) : lineEnd(s, p);
      const next = before ? s.slice(0, at) + body + "\n" + s.slice(at) : s.slice(0, at) + "\n" + body + s.slice(at);
      this.replaceText(ed, next, before ? at : at + 1, true);
      return;
    }
    const at = before || s.length === 0 ? p : Math.min(p + 1, lineEnd(s, p));
    this.replaceText(ed, s.slice(0, at) + body + s.slice(at), at + body.length - 1, true);
  }

  // --- command parser -------------------------------------------------------

  /** Runs a complete normal-mode command; returns "incomplete" to wait for more keys. */
  private execute(ed: EditorInternals, keys: string): "done" | "incomplete" {
    const m = /^([1-9]\d*)?(.*)$/s.exec(keys)!;
    const count1 = m[1] ? Number(m[1]) : 1;
    let rest = m[2]!;
    if (!rest) return "incomplete";

    const op = OPERATORS.has(rest[0]!) ? rest[0]! : undefined;
    if (!op) return this.runAction(ed, rest, count1);

    rest = rest.slice(1);
    const m2 = /^([1-9]\d*)?(.*)$/s.exec(rest)!;
    const count = count1 * (m2[1] ? Number(m2[1]) : 1);
    const motionKeys = m2[2]!;
    if (!motionKeys) return "incomplete";

    const s = this.text(ed);
    const p = this.offset(ed);
    let range: Range | undefined;

    if (motionKeys === op) {
      // dd / cc / yy: count lines from the cursor line.
      let end = p;
      for (let i = 1; i < count; i++) end = Math.min(lineEnd(s, end) + 1, s.length);
      range = { start: p, end: lineEnd(s, end), linewise: true };
    } else if (motionKeys[0] === "i" || motionKeys[0] === "a") {
      if (motionKeys.length < 2) return "incomplete";
      range = textObject(s, p, motionKeys[0] as "i" | "a", motionKeys[1]!);
    } else if (op === "c" && (motionKeys === "w" || motionKeys === "W") && charClass(s[p], false) !== 0) {
      // Vim special case: cw on a word changes to the end of the word, keeping trailing space.
      const big = motionKeys === "W";
      let q = p;
      while (q + 1 < s.length && charClass(s[q + 1], big) === charClass(s[p], big) && s[q + 1] !== "\n") q++;
      for (let i = 1; i < count; i++) q = wordEnd(s, q, big);
      range = { start: p, end: q + 1, linewise: false };
    } else {
      const motion = this.motion(s, p, motionKeys, count, true);
      if (motion === "incomplete") return "incomplete";
      if (motion) {
        const start = Math.min(p, motion.to);
        const end = Math.max(p, motion.to) + (motion.inclusive ? 1 : 0);
        range = { start, end, linewise: Boolean(motion.linewise) };
      }
    }

    if (!range) return "done";
    if (op === "y") this.yankRange(ed, range);
    else {
      this.deleteRange(ed, range, op === "c");
      if (op === "c") this.mode = "insert";
    }
    return "done";
  }

  /** Resolves a motion; undefined when it can't move (e.g. f to a missing char). */
  private motion(s: string, p: number, keys: string, count: number, forOperator: boolean): Motion | undefined | "incomplete" {
    const k = keys[0]!;
    if ("fFtT".includes(k)) {
      if (keys.length < 2) return "incomplete";
      const cmd: FindCommand = { kind: k as FindCommand["kind"], char: keys[1]! };
      this.lastFind = cmd;
      return this.repeatFind(s, p, cmd, count);
    }
    if (keys === "g") return "incomplete";
    if (keys.length > 1 && keys !== "gg") return undefined;

    let to = p;
    switch (k) {
      case "h":
        return { to: Math.max(lineStart(s, p), p - count), inclusive: false };
      case "l": {
        const le = lineEnd(s, p);
        return { to: Math.min(forOperator ? le : Math.max(le - 1, lineStart(s, p)), p + count), inclusive: false };
      }
      case "w":
      case "W":
        for (let i = 0; i < count; i++) to = wordForward(s, to, k === "W");
        // An operator never takes a word motion across the line break.
        if (forOperator && s.slice(p, to).includes("\n")) to = lineEnd(s, p);
        return { to, inclusive: false };
      case "e":
      case "E":
        for (let i = 0; i < count; i++) to = wordEnd(s, to, k === "E");
        return { to, inclusive: true };
      case "b":
      case "B":
        for (let i = 0; i < count; i++) to = wordBack(s, to, k === "B");
        return { to, inclusive: false };
      case "0":
        return { to: lineStart(s, p), inclusive: false };
      case "^": {
        let q = lineStart(s, p);
        while (q < s.length && s[q] !== "\n" && /\s/.test(s[q]!)) q++;
        return { to: q, inclusive: false };
      }
      case "$":
        to = lineEnd(s, p);
        return forOperator ? { to, inclusive: false } : { to: Math.max(to - 1, lineStart(s, p)), inclusive: false };
      case ";":
      case ",": {
        if (!this.lastFind) return undefined;
        const flip: Record<FindCommand["kind"], FindCommand["kind"]> = { f: "F", F: "f", t: "T", T: "t" };
        const cmd = k === ";" ? this.lastFind : { ...this.lastFind, kind: flip[this.lastFind.kind] };
        return this.repeatFind(s, p, cmd, count);
      }
      case "j":
      case "k": {
        if (!forOperator) return undefined; // plain j/k use pi's visual-line movement
        let q = p;
        for (let i = 0; i < count; i++) q = k === "j" ? Math.min(lineEnd(s, q) + 1, s.length) : Math.max(lineStart(s, q) - 1, 0);
        return { to: q, inclusive: false, linewise: true };
      }
      case "G":
        return { to: lineStart(s, s.length), inclusive: false, linewise: forOperator };
      case "g":
        return { to: 0, inclusive: false, linewise: forOperator };
      default:
        return undefined;
    }
  }

  private repeatFind(s: string, p: number, cmd: FindCommand, count: number): Motion | undefined {
    let to: number | undefined = p;
    for (let i = 0; i < count && to !== undefined; i++) {
      // Repeating t/T from right before the target would not move; step past it.
      const from = i > 0 && (cmd.kind === "t" || cmd.kind === "T") ? (cmd.kind === "t" ? to + 1 : to - 1) : to;
      to = findOnLine(s, from, cmd);
    }
    return to === undefined ? undefined : { to, inclusive: cmd.kind === "f" || cmd.kind === "t" };
  }

  /** Non-operator commands: motions, inserts, single-key edits. */
  private runAction(ed: EditorInternals, keys: string, count: number): "done" | "incomplete" {
    const s = this.text(ed);
    const p = this.offset(ed);
    const ls = lineStart(s, p);
    const le = lineEnd(s, p);

    switch (keys) {
      case "i":
        this.mode = "insert";
        return "done";
      case "a":
        this.mode = "insert";
        this.moveTo(ed, Math.min(p + 1, le), false);
        return "done";
      case "I":
        this.mode = "insert";
        this.moveTo(ed, (this.motion(s, p, "^", 1, false) as Motion).to, false);
        return "done";
      case "A":
        this.mode = "insert";
        this.moveTo(ed, le, false);
        return "done";
      case "o":
        this.mode = "insert";
        this.replaceText(ed, s.slice(0, le) + "\n" + s.slice(le), le + 1, false);
        return "done";
      case "O":
        this.mode = "insert";
        this.replaceText(ed, s.slice(0, ls) + "\n" + s.slice(ls), ls, false);
        return "done";
      case "x":
        if (le > p) this.deleteRange(ed, { start: p, end: Math.min(p + count, le), linewise: false }, false);
        return "done";
      case "X":
        if (p > ls) this.deleteRange(ed, { start: Math.max(ls, p - count), end: p, linewise: false }, false);
        return "done";
      case "s":
        this.deleteRange(ed, { start: p, end: Math.min(p + count, le), linewise: false }, true);
        this.mode = "insert";
        return "done";
      case "S":
        return this.execute(ed, `${count}cc`);
      case "D":
        this.deleteRange(ed, { start: p, end: le, linewise: false }, false);
        return "done";
      case "C":
        this.deleteRange(ed, { start: p, end: le, linewise: false }, true);
        this.mode = "insert";
        return "done";
      case "Y":
        return this.execute(ed, `${count}yy`);
      case "p":
      case "P":
        this.put(ed, keys === "P", count);
        return "done";
      case "u":
        for (let i = 0; i < count; i++) ed.undo();
        this.moveTo(ed, this.offset(ed));
        return "done";
      case "j":
      case "k":
        for (let i = 0; i < count; i++) super.handleInput(keys === "j" ? KEY_DOWN : KEY_UP);
        return "done";
    }

    if (keys[0] === "r") {
      if (keys.length < 2) return "incomplete";
      if (p + count <= le) {
        const next = s.slice(0, p) + keys[1]!.repeat(count) + s.slice(p + count);
        this.replaceText(ed, next, p + count - 1, true);
      }
      return "done";
    }

    const motion = this.motion(s, p, keys, count, false);
    if (motion === "incomplete") return "incomplete";
    if (motion) this.moveTo(ed, motion.to);
    return "done";
  }

  render(width: number): string[] {
    const lines = super.render(width);
    if (lines.length === 0) return lines;
    const label = this.mode === "normal" ? ` NORMAL${this.pending ? ` ${this.pending}` : ""} ` : " INSERT ";
    const last = lines.length - 1;
    if (visibleWidth(lines[last]!) >= label.length) {
      lines[last] = truncateToWidth(lines[last]!, width - label.length, "") + label;
    }
    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  // Agent-driven panes (manager workers) need Esc to mean abort, not "normal mode".
  pi.registerFlag("no-vim", { description: "Use the plain editor instead of vim mode", type: "boolean", default: false });

  pi.on("session_start", (_event, ctx) => {
    if (pi.getFlag("no-vim") === true) return;
    ctx.ui.setEditorComponent((tui, theme, keybindings) => new VimEditor(tui, theme, keybindings));
  });
}
