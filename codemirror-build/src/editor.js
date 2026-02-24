import { EditorView, Decoration, ViewPlugin, WidgetType, keymap, placeholder } from "@codemirror/view";
import { EditorState, RangeSetBuilder } from "@codemirror/state";
import { markdown, markdownLanguage } from "@codemirror/lang-markdown";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";

// ─── Widgets ─────────────────────────────────────────────────────

class CheckboxWidget extends WidgetType {
  constructor(checked, lineNo) {
    super();
    this.checked = checked;
    this.lineNo = lineNo;
  }
  toDOM() {
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.className = "cm-checkbox-widget";
    cb.checked = this.checked;
    cb.addEventListener("mousedown", (e) => {
      e.preventDefault();
      toggleCheckbox(this.lineNo);
    });
    return cb;
  }
  eq(other) { return this.checked === other.checked && this.lineNo === other.lineNo; }
  ignoreEvent() { return false; }
}

class BulletWidget extends WidgetType {
  toDOM() {
    const span = document.createElement("span");
    span.className = "cm-bullet-widget";
    span.textContent = "\u2022";
    return span;
  }
  eq() { return true; }
  ignoreEvent() { return true; }
}

class HRWidget extends WidgetType {
  toDOM() {
    const div = document.createElement("div");
    div.className = "cm-hr-widget";
    return div;
  }
  eq() { return true; }
  ignoreEvent() { return true; }
}


function toggleCheckbox(lineNo) {
  if (!window._cmView) return;
  const view = window._cmView;
  const line = view.state.doc.line(lineNo);
  const text = line.text;
  let newText;
  if (/\[x\]/i.test(text)) newText = text.replace(/\[x\]/i, "[ ]");
  else if (/\[ \]/.test(text)) newText = text.replace(/\[ \]/, "[x]");
  else return;
  view.dispatch({ changes: { from: line.from, to: line.to, insert: newText } });
  if (window.webkit?.messageHandlers?.checkboxToggled) {
    window.webkit.messageHandlers.checkboxToggled.postMessage({
      line: lineNo, checked: /\[x\]/i.test(newText)
    });
  }
}

// ─── Decoration helpers ──────────────────────────────────────────

function hide(from, to) {
  return { from, to, deco: Decoration.replace({}) };
}

function mark(from, to, cls) {
  return { from, to, deco: Decoration.mark({ class: cls }) };
}

function replaceWith(from, to, widget) {
  return { from, to, deco: Decoration.replace({ widget }) };
}

function lineDeco(from, cls) {
  return { from, to: from, deco: Decoration.line({ class: cls }), isLine: true };
}

// ─── Main decoration plugin ─────────────────────────────────────

const markdownDecorations = ViewPlugin.fromClass(
  class {
    constructor(view) { this.decorations = this.build(view); }

    update(update) {
      if (update.docChanged || update.viewportChanged || update.selectionSet) {
        this.decorations = this.build(update.view);
      }
    }

    build(view) {
      const doc = view.state.doc;
      const sel = view.state.selection.main;
      const curL1 = doc.lineAt(sel.from).number;
      const curL2 = doc.lineAt(sel.to).number;
      const active = (n) => n >= curL1 && n <= curL2;

      // Find code blocks
      let inCode = false, codeStart = 0;
      const codeBlocks = [];
      for (let i = 1; i <= doc.lines; i++) {
        if (/^```/.test(doc.line(i).text)) {
          if (!inCode) { codeStart = i; inCode = true; }
          else { codeBlocks.push([codeStart, i]); inCode = false; }
        }
      }
      if (inCode) codeBlocks.push([codeStart, doc.lines]);

      // Find table regions (consecutive lines starting with |)
      const tableLines = new Map(); // lineNo → "header" | "sep" | "row"
      for (let i = 1; i <= doc.lines; i++) {
        const t = doc.line(i).text.trimStart();
        if (!t.startsWith("|")) continue;
        // Check if this is a separator: | --- | --- |
        if (/^\|?(\s*:?-{1,}:?\s*\|)+(\s*:?-{1,}:?\s*\|?)$/.test(t)) {
          // Verify previous line is also a table line (header)
          if (i > 1 && tableLines.has(i - 1)) {
            tableLines.set(i - 1, "header"); // upgrade previous to header
            tableLines.set(i, "sep");
          }
        } else if (/^\|.*\|$/.test(t)) {
          // Data row or header row
          if (tableLines.has(i - 1)) {
            // Continuation of a table
            const prevType = tableLines.get(i - 1);
            tableLines.set(i, (prevType === "sep" || prevType === "row") ? "row" : "pending");
          } else {
            // Could be start of a table (header) — mark as pending
            tableLines.set(i, "pending");
          }
        }
      }
      // Clean up: remove "pending" lines that never became part of a table
      for (const [lineNo, type] of tableLines) {
        if (type === "pending") tableLines.delete(lineNo);
      }

      const decos = [];

      for (let i = 1; i <= doc.lines; i++) {
        const line = doc.line(i);
        const t = line.text;
        const act = active(i);

        // ── Code blocks ──
        const cb = codeBlocks.find(([s, e]) => i >= s && i <= e);
        if (cb) {
          if (i === cb[0] || i === cb[1]) {
            decos.push(lineDeco(line.from, "cm-codeblock-line cm-fence-line"));
            decos.push(mark(line.from, line.to, "cm-fence-text"));
          } else {
            decos.push(lineDeco(line.from, "cm-codeblock-line"));
          }
          continue;
        }

        // ── Heading ──
        const hm = t.match(/^(#{1,6})\s/);
        if (hm) {
          decos.push(lineDeco(line.from, "cm-heading-" + hm[1].length));
          if (!act) {
            decos.push(hide(line.from, line.from + hm[0].length));
          } else {
            decos.push(mark(line.from, line.from + hm[1].length, "cm-syntax-mark cm-heading-mark"));
          }
          this.inlines(line, t, decos, act, hm[0].length);
          continue;
        }

        // ── Blockquote ──
        const bq = t.match(/^(\s*>+\s*)/);
        if (bq) {
          decos.push(lineDeco(line.from, "cm-blockquote-line"));
          if (!act) {
            decos.push(hide(line.from, line.from + bq[1].length));
          } else {
            decos.push(mark(line.from, line.from + bq[1].length, "cm-syntax-mark"));
          }
          this.inlines(line, t, decos, act, bq[1].length);
          continue;
        }

        // ── Horizontal rule ──
        if (/^(\*{3,}|-{3,}|_{3,})\s*$/.test(t)) {
          if (!act) {
            decos.push(replaceWith(line.from, line.to, new HRWidget()));
          } else {
            decos.push(lineDeco(line.from, "cm-hr-active"));
            decos.push(mark(line.from, line.to, "cm-syntax-mark"));
          }
          continue;
        }

        // ── Checkbox ──
        const ck = t.match(/^(\s*)([-*+]\s+\[[ xX]\]\s)/);
        if (ck) {
          const checked = /\[x\]/i.test(ck[2]);
          const indent = Math.floor(ck[1].length / 2);
          const ckStart = line.from + ck[1].length;
          const ckEnd = line.from + ck[0].length;
          if (indent > 0) {
            decos.push(lineDeco(line.from, "cm-list-indent-" + Math.min(indent, 4)));
            decos.push(hide(line.from, line.from + ck[1].length));
          }
          decos.push(replaceWith(ckStart, ckEnd, new CheckboxWidget(checked, i)));
          this.inlines(line, t, decos, act, ck[0].length);
          continue;
        }

        // ── Unordered list ──
        const ul = t.match(/^(\s*)([-*+])(\s+)/);
        if (ul) {
          const indent = Math.floor(ul[1].length / 2);
          const mStart = line.from + ul[1].length;
          const mEnd = line.from + ul[0].length;
          if (indent > 0) {
            decos.push(lineDeco(line.from, "cm-list-indent-" + Math.min(indent, 4)));
            decos.push(hide(line.from, line.from + ul[1].length));
          }
          if (!act) {
            decos.push(replaceWith(mStart, mEnd, new BulletWidget()));
          } else {
            decos.push(mark(mStart, mEnd, "cm-list-mark"));
          }
          this.inlines(line, t, decos, act, ul[0].length);
          continue;
        }

        // ── Ordered list ──
        const ol = t.match(/^(\s*)(\d+[.)]\s+)/);
        if (ol) {
          const indent = Math.floor(ol[1].length / 2);
          if (indent > 0) {
            decos.push(lineDeco(line.from, "cm-list-indent-" + Math.min(indent, 4)));
            decos.push(hide(line.from, line.from + ol[1].length));
          }
          const numStart = line.from + ol[1].length;
          const numEnd = line.from + ol[0].length;
          decos.push(mark(numStart, numEnd, "cm-list-mark"));
          this.inlines(line, t, decos, act, ol[0].length);
          continue;
        }

        // ── Table lines ──
        const tableType = tableLines.get(i);
        if (tableType) {
          if (tableType === "header") {
            decos.push(lineDeco(line.from, "cm-table-header"));
          } else if (tableType === "sep") {
            if (!act) {
              decos.push(lineDeco(line.from, "cm-table-sep"));
            } else {
              decos.push(lineDeco(line.from, "cm-table-sep"));
              decos.push(mark(line.from, line.to, "cm-syntax-mark"));
            }
          } else {
            decos.push(lineDeco(line.from, "cm-table-row"));
          }
          // Dim pipe characters on non-active lines
          if (tableType !== "sep") {
            let pipeIdx = t.indexOf("|");
            while (pipeIdx !== -1) {
              decos.push(mark(line.from + pipeIdx, line.from + pipeIdx + 1, "cm-table-pipe"));
              pipeIdx = t.indexOf("|", pipeIdx + 1);
            }
          }
          continue;
        }

        // ── Regular line ──
        this.inlines(line, t, decos, act, 0);
      }

      // Sort by from, lines first at same position
      decos.sort((a, b) => {
        if (a.from !== b.from) return a.from - b.from;
        if (a.isLine !== b.isLine) return a.isLine ? -1 : 1;
        return a.to - b.to;
      });

      // Remove overlapping non-line decorations
      const out = [];
      let end = -1;
      for (const d of decos) {
        if (d.isLine) { out.push(d); continue; }
        if (d.from >= end) { out.push(d); end = d.to; }
      }

      const builder = new RangeSetBuilder();
      for (const d of out) builder.add(d.from, d.to, d.deco);
      return builder.finish();
    }

    inlines(line, text, decos, active, skip) {
      const src = text.substring(skip);
      const off = line.from + skip;
      let m;

      // Inline code `code`
      const codeRe = /`([^`]+)`/g;
      while ((m = codeRe.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        if (!active) {
          decos.push(hide(s, s + 1));
          decos.push(mark(s + 1, e - 1, "cm-inline-code"));
          decos.push(hide(e - 1, e));
        } else {
          decos.push(mark(s, s + 1, "cm-syntax-mark"));
          decos.push(mark(s + 1, e - 1, "cm-inline-code"));
          decos.push(mark(e - 1, e, "cm-syntax-mark"));
        }
      }

      // Bold **text** or __text__
      const boldRe = /(\*\*|__)(.+?)\1/g;
      while ((m = boldRe.exec(src)) !== null) {
        const s = off + m.index, ml = m[1].length, e = s + m[0].length;
        if (!active) {
          decos.push(hide(s, s + ml));
          decos.push(mark(s + ml, e - ml, "cm-strong"));
          decos.push(hide(e - ml, e));
        } else {
          decos.push(mark(s, s + ml, "cm-syntax-mark"));
          decos.push(mark(s + ml, e - ml, "cm-strong"));
          decos.push(mark(e - ml, e, "cm-syntax-mark"));
        }
      }

      // Italic *text* (not **)
      const italRe = /(?<!\*)\*(?!\*)(.+?)\*(?!\*)/g;
      while ((m = italRe.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        if (!active) {
          decos.push(hide(s, s + 1));
          decos.push(mark(s + 1, e - 1, "cm-emphasis"));
          decos.push(hide(e - 1, e));
        } else {
          decos.push(mark(s, s + 1, "cm-syntax-mark"));
          decos.push(mark(s + 1, e - 1, "cm-emphasis"));
          decos.push(mark(e - 1, e, "cm-syntax-mark"));
        }
      }

      // Italic _text_ (not __)
      const italRe2 = /(?<!_)_(?!_)(.+?)_(?!_)/g;
      while ((m = italRe2.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        if (!active) {
          decos.push(hide(s, s + 1));
          decos.push(mark(s + 1, e - 1, "cm-emphasis"));
          decos.push(hide(e - 1, e));
        } else {
          decos.push(mark(s, s + 1, "cm-syntax-mark"));
          decos.push(mark(s + 1, e - 1, "cm-emphasis"));
          decos.push(mark(e - 1, e, "cm-syntax-mark"));
        }
      }

      // Strikethrough ~~text~~
      const strikeRe = /~~(.+?)~~/g;
      while ((m = strikeRe.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        if (!active) {
          decos.push(hide(s, s + 2));
          decos.push(mark(s + 2, e - 2, "cm-strikethrough"));
          decos.push(hide(e - 2, e));
        } else {
          decos.push(mark(s, s + 2, "cm-syntax-mark"));
          decos.push(mark(s + 2, e - 2, "cm-strikethrough"));
          decos.push(mark(e - 2, e, "cm-syntax-mark"));
        }
      }

      // Links [text](url)
      const linkRe = /\[([^\]]+)\]\(([^)]+)\)/g;
      while ((m = linkRe.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        const tEnd = s + 1 + m[1].length;
        if (!active) {
          decos.push(hide(s, s + 1));                    // [
          decos.push(mark(s + 1, tEnd, "cm-link"));      // text
          decos.push(hide(tEnd, e));                      // ](url)
        } else {
          decos.push(mark(s, s + 1, "cm-syntax-mark"));        // [
          decos.push(mark(s + 1, tEnd, "cm-link"));             // text
          decos.push(mark(tEnd, tEnd + 2, "cm-syntax-mark"));   // ](
          decos.push(mark(tEnd + 2, e - 1, "cm-url"));          // url
          decos.push(mark(e - 1, e, "cm-syntax-mark"));         // )
        }
      }

      // Images ![alt](src) — show as link-like
      const imgRe = /!\[([^\]]*)\]\(([^)]+)\)/g;
      while ((m = imgRe.exec(src)) !== null) {
        const s = off + m.index, e = s + m[0].length;
        const altEnd = s + 2 + m[1].length;
        if (!active) {
          decos.push(hide(s, s + 2));                     // ![
          decos.push(mark(s + 2, altEnd, "cm-link"));     // alt
          decos.push(hide(altEnd, e));                     // ](src)
        } else {
          decos.push(mark(s, s + 2, "cm-syntax-mark"));
          decos.push(mark(s + 2, altEnd, "cm-link"));
          decos.push(mark(altEnd, altEnd + 2, "cm-syntax-mark"));
          decos.push(mark(altEnd + 2, e - 1, "cm-url"));
          decos.push(mark(e - 1, e, "cm-syntax-mark"));
        }
      }
    }
  },
  { decorations: (v) => v.decorations }
);

// ─── List continuation on Enter ──────────────────────────────────

function listContinuation({ state, dispatch }) {
  const { from, to } = state.selection.main;
  if (from !== to) return false;
  const line = state.doc.lineAt(from);
  const t = line.text;

  // Checkbox: "  - [ ] content" or "  - [x] content"
  const ck = t.match(/^(\s*)([-*+])(\s+)\[[ xX]\]\s(.*)/);
  if (ck) {
    if (!ck[4].trim()) {
      // Empty checkbox line — remove it
      dispatch({ changes: { from: line.from, to: line.to, insert: "" }, selection: { anchor: line.from } });
      return true;
    }
    // Continue with new unchecked checkbox, preserving indent
    const ins = "\n" + ck[1] + ck[2] + ck[3] + "[ ] ";
    dispatch({ changes: { from, to, insert: ins }, selection: { anchor: from + ins.length } });
    return true;
  }

  // Unordered list: "  - content"
  const bul = t.match(/^(\s*)([-*+])(\s+)(.*)/);
  if (bul) {
    if (!bul[4].trim()) {
      dispatch({ changes: { from: line.from, to: line.to, insert: "" }, selection: { anchor: line.from } });
      return true;
    }
    const ins = "\n" + bul[1] + bul[2] + bul[3];
    dispatch({ changes: { from, to, insert: ins }, selection: { anchor: from + ins.length } });
    return true;
  }

  // Ordered list: "  1. content"
  const num = t.match(/^(\s*)(\d+)([.)]\s+)(.*)/);
  if (num) {
    if (!num[4].trim()) {
      dispatch({ changes: { from: line.from, to: line.to, insert: "" }, selection: { anchor: line.from } });
      return true;
    }
    const ins = "\n" + num[1] + (parseInt(num[2]) + 1) + num[3];
    dispatch({ changes: { from, to, insert: ins }, selection: { anchor: from + ins.length } });
    return true;
  }

  return false;
}

function isList(text) {
  return /^\s*[-*+]\s/.test(text) || /^\s*\d+[.)]\s/.test(text);
}

function listIndent({ state, dispatch }) {
  const line = state.doc.lineAt(state.selection.main.from);
  if (isList(line.text)) {
    dispatch({
      changes: { from: line.from, insert: "  " },
      selection: { anchor: state.selection.main.from + 2 }
    });
    return true;
  }
  return false;
}

function listDedent({ state, dispatch }) {
  const line = state.doc.lineAt(state.selection.main.from);
  if (!isList(line.text)) return false;
  const m = line.text.match(/^(\s+)/);
  if (m) {
    const n = Math.min(2, m[1].length);
    dispatch({
      changes: { from: line.from, to: line.from + n },
      selection: { anchor: Math.max(line.from, state.selection.main.from - n) }
    });
    return true;
  }
  return false;
}

// ─── Text change listener ────────────────────────────────────────

let debounceTimer = null;
const textChangeListener = EditorView.updateListener.of((update) => {
  if (update.docChanged) {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      if (window.webkit?.messageHandlers?.textChanged) {
        window.webkit.messageHandlers.textChanged.postMessage(update.state.doc.toString());
      }
    }, 50);
  }
});

// ─── Theme ───────────────────────────────────────────────────────

const baseTheme = EditorView.theme({
  "&": { backgroundColor: "transparent" },
  ".cm-content": { caretColor: "var(--cm-fg-color, #333)" },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground": {
    backgroundColor: "rgba(128, 128, 128, 0.25)",
  },
});

// ─── Initialize ──────────────────────────────────────────────────

const view = new EditorView({
  state: EditorState.create({
    doc: "",
    extensions: [
      baseTheme,
      markdown({ base: markdownLanguage }),
      markdownDecorations,
      textChangeListener,
      keymap.of([
        { key: "Enter", run: listContinuation },
        { key: "Tab", run: listIndent },
        { key: "Shift-Tab", run: listDedent },
        ...historyKeymap,
        ...defaultKeymap,
      ]),
      history(),
      placeholder("Start typing\u2026"),
      EditorView.lineWrapping,
      EditorState.allowMultipleSelections.of(false),
    ],
  }),
  parent: document.getElementById("editor"),
});

window._cmView = view;

// ─── Bridge ──────────────────────────────────────────────────────

window.cmSetText = function (text) {
  if (view.state.doc.toString() !== text)
    view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text } });
};

window.cmGetText = function () { return view.state.doc.toString(); };

window.cmSetTheme = function (bgColor) {
  // Only set body bg for opaque note colors; transparent lets material show through
  if (bgColor && bgColor !== "transparent" && !/rgba?\(0,\s*0,\s*0,\s*0/.test(bgColor)) {
    document.body.style.backgroundColor = bgColor;
  } else {
    document.body.style.backgroundColor = "transparent";
  }
};

window.cmFocus = function () { view.focus(); };

if (window.webkit?.messageHandlers?.editorReady)
  window.webkit.messageHandlers.editorReady.postMessage(true);
