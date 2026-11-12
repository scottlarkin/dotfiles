// Muninn memory for pi: maps pi lifecycle events onto the `muninn hook *`
// contract (~/repos/munnin/docs/CONTRACT.md) that the Claude Code plugin uses.
//
// Muninn parses Claude Code JSONL transcripts, so we keep a Claude-format
// shadow transcript of the current pi branch and pass its path to the hooks.

import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const MUNINN_PATH = `${process.env.PATH ?? ""}:${join(homedir(), "go", "bin")}`;
const TRANSCRIPT_DIR = join(homedir(), ".pi", "agent", "muninn", "transcripts");
const FILE_TOOLS = new Set(["read", "edit", "write"]);
const EDIT_TOOLS = new Set(["edit", "write"]);

type HookName = "prompt" | "stop" | "warm" | "session-end" | "file-context" | "reindex";

// Hooks always exit 0 and print nothing on failure, so every error here
// degrades to "no context" rather than breaking the turn.
function runHook(hook: HookName, payload: { cwd: string }, timeoutMs: number): Promise<string> {
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn("muninn", ["hook", hook], {
        cwd: payload.cwd,
        env: { ...process.env, PATH: MUNINN_PATH },
        stdio: ["pipe", "pipe", "ignore"],
      });
    } catch {
      resolve("");
      return;
    }
    let stdout = "";
    const timer = setTimeout(() => child.kill("SIGKILL"), timeoutMs);
    child.stdout.on("data", (d) => (stdout += d));
    child.on("error", () => {
      clearTimeout(timer);
      resolve("");
    });
    child.on("close", () => {
      clearTimeout(timer);
      resolve(parseContext(stdout));
    });
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(payload));
  });
}

function parseContext(stdout: string): string {
  if (!stdout.trim()) return "";
  try {
    return JSON.parse(stdout)?.hookSpecificOutput?.additionalContext ?? "";
  } catch {
    return "";
  }
}

type Block = { type: string; text?: string; id?: string; name?: string; arguments?: unknown };

function textOf(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return (content as Block[])
    .filter((b) => b.type === "text" && b.text)
    .map((b) => b.text)
    .join("\n");
}

// Converts pi messages into the {type, message:{role, content}} lines muninn's
// transcript decoder expects (user text, assistant text/tool_use, tool_result).
function toClaudeLine(message: any): object | undefined {
  switch (message?.role) {
    case "user": {
      const text = textOf(message.content);
      return text ? { type: "user", message: { role: "user", content: text } } : undefined;
    }
    case "assistant": {
      const content = (message.content as Block[]).flatMap((b) => {
        if (b.type === "text" && b.text) return [{ type: "text", text: b.text }];
        if (b.type === "toolCall") return [{ type: "tool_use", id: b.id, name: b.name, input: b.arguments ?? {} }];
        return [];
      });
      return content.length ? { type: "assistant", message: { role: "assistant", content } } : undefined;
    }
    case "toolResult":
      return {
        type: "user",
        message: {
          role: "user",
          content: [
            {
              type: "tool_result",
              tool_use_id: message.toolCallId,
              is_error: Boolean(message.isError),
              content: textOf(message.content),
            },
          ],
        },
      };
    default:
      return undefined;
  }
}

function writeTranscript(ctx: ExtensionContext): string {
  const path = join(TRANSCRIPT_DIR, `${ctx.sessionManager.getSessionId()}.jsonl`);
  try {
    mkdirSync(TRANSCRIPT_DIR, { recursive: true });
    const lines = ctx.sessionManager
      .getBranch()
      .flatMap((entry: any) => (entry.type === "message" ? [toClaudeLine(entry.message)] : []))
      .filter(Boolean)
      .map((line) => JSON.stringify(line));
    writeFileSync(path, lines.length ? lines.join("\n") + "\n" : "");
  } catch {
    return "";
  }
  return path;
}

function basePayload(ctx: ExtensionContext, event: string) {
  return { session_id: ctx.sessionManager.getSessionId(), cwd: ctx.cwd, hook_event_name: event };
}

export default function (pi: ExtensionAPI) {
  if (process.env.MUNINN_DISABLE === "1") return;

  pi.on("session_start", async (event, ctx) => {
    void runHook("warm", { ...basePayload(ctx, "SessionStart"), source: event.reason }, 10_000);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (event.messageType !== "user" || !event.prompt?.trim()) return;
    const context = await runHook(
      "prompt",
      { ...basePayload(ctx, "UserPromptSubmit"), prompt: event.prompt, transcript_path: writeTranscript(ctx) },
      30_000,
    );
    if (!context) return;
    return { message: { customType: "muninn-recall", content: context, display: false } };
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!FILE_TOOLS.has(event.toolName)) return;
    const toolInput = event.input as { path?: string };
    if (!toolInput?.path) return;
    const payload = { ...basePayload(ctx, "PostToolUse"), tool_name: event.toolName, tool_input: toolInput, tool_use_id: event.toolCallId };

    if (EDIT_TOOLS.has(event.toolName) && !event.isError) void runHook("reindex", payload, 10_000);

    const context = await runHook("file-context", { ...payload, hook_event_name: "PreToolUse" }, 10_000);
    if (!context) return;
    return { content: [...event.content, { type: "text", text: `\n\n${context}` }] };
  });

  pi.on("agent_settled", async (_event, ctx) => {
    void runHook("stop", { ...basePayload(ctx, "Stop"), transcript_path: writeTranscript(ctx), stop_hook_active: false }, 30_000);
  });

  pi.on("session_shutdown", async (event, ctx) => {
    await runHook("session-end", { ...basePayload(ctx, "SessionEnd"), reason: event.reason }, 10_000);
  });
}
