import { execFile } from "child_process";
import { promises as fs } from "fs";
import * as os from "os";
import * as path from "path";
import { promisify } from "util";

/**
 * OpenClaw Plugin: Huginn Automation Platform Integration
 *
 * 为 OpenClaw agents 提供 Huginn 自动化管理能力:
 * - 列出/查看/更新 agents
 * - 手动触发 agent 运行
 * - 获取 events 和 logs
 * - 注入手动 event
 * - 聚合查看完整流水线状态
 *
 * Auth: Huginn uses cookie-based sessions with CSRF tokens.
 * Login once at plugin load, re-login on 401/redirect.
 */

interface HuginnConfig {
    huginnUrl?: string;
    username?: string;
    password?: string;
}

const PLUGIN_VERSION = "1.1.1";
const LOGIN_MAX_FAILURES_BEFORE_DEFER = 3;
const LOGIN_RETRY_BACKOFF_MS = 5 * 60 * 1000;
const CURL_TIMEOUT_SECONDS = 15;
const RECENT_AGENT_ERROR_WINDOW_MS = 24 * 60 * 60 * 1000;
const execFileAsync = promisify(execFile);
const CRITICAL_AGENT_NAME_PATTERNS = [
    /digest/i,
    /bridge/i,
    /formatter/i,
    /dedup/i,
    /fetcher/i,
];

// ─── Session state (module-level, shared across tool calls) ───

let sessionCookie = "";
let csrfToken = "";
let userToken = ""; // Huginn API user_credential token
let pluginApi: any = null; // set once in register()
let loginPromise: Promise<void> | null = null;
let loginFailures = 0;
let lastLoginFailureAt = 0;
let lastLoginError = "";
let loginDeferred = false;
let curlFallbackLogged = false;

function getConfig(): { huginnUrl: string; username: string; password: string } {
    const api = pluginApi;
    if (!api) throw new Error("[huginn] Plugin not initialized — register() not called");
    const fullConfig = api.config ?? {};
    const cfg: HuginnConfig = fullConfig?.plugins?.entries?.huginn?.config ?? fullConfig ?? {};
    const huginnUrl = cfg.huginnUrl || process.env.HUGINN_URL || "";
    const username = cfg.username || process.env.HUGINN_USERNAME || "admin";
    const password = cfg.password || process.env.HUGINN_PASSWORD || "";

    if (!huginnUrl) {
        throw new Error(
            "Huginn URL 未配置。请设置 HUGINN_URL 环境变量，或在 openclaw.json 的 plugins.entries.huginn.config.huginnUrl 中配置"
        );
    }
    if (!/^https?:\/\//i.test(huginnUrl)) {
        throw new Error(`Huginn URL 必须以 http:// 或 https:// 开头，当前值: ${huginnUrl}`);
    }
    if (!password) {
        throw new Error(
            "Huginn password 未配置。请设置 HUGINN_PASSWORD 环境变量，或在 openclaw.json 的 plugins.entries.huginn.config.password 中配置"
        );
    }
    return { huginnUrl: huginnUrl.replace(/\/+$/, ""), username, password };
}

// ─── Auth helpers ───

function clearAuthState(): void {
    sessionCookie = "";
    csrfToken = "";
    userToken = "";
}

function formatDeferredRetryAt(ts: number): string {
    return new Date(ts).toISOString();
}

async function login(): Promise<void> {
    const { huginnUrl, username, password } = getConfig();

    // Step 1: GET /users/sign_in to get CSRF token and session cookie
    const loginPage = await requestWithFallback(`${huginnUrl}/users/sign_in`, {
        redirect: "manual",
        headers: { Accept: "text/html" },
    });
    const loginHtml = await loginPage.text();
    const cookies = extractCookies(loginPage.headers);

    const csrfMatch = loginHtml.match(/name="authenticity_token"\s+value="([^"]+)"/);
    if (!csrfMatch) {
        throw new Error("无法从 Huginn 登录页面获取 CSRF token — 确认 huginnUrl 正确");
    }

    // Step 2: POST /users/sign_in with credentials
    const formBody = new URLSearchParams({
        "authenticity_token": csrfMatch[1],
        "user[login]": username,
        "user[password]": password,
        "commit": "Sign in",
    });

    const loginRes = await requestWithFallback(`${huginnUrl}/users/sign_in`, {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            Cookie: cookies,
        },
        body: formBody.toString(),
        redirect: "manual",
    });

    const postCookies = extractCookies(loginRes.headers);
    sessionCookie = mergeCookies(cookies, postCookies);

    // Verify login success (302 redirect to / means success, 200 means failure)
    if (loginRes.status !== 302 && loginRes.status !== 303) {
        throw new Error(`Huginn 登录失败 (status ${loginRes.status}) — 请检查用户名/密码`);
    }

    // Step 3: Follow redirect, extract fresh CSRF token and user_credential token
    // [SEC] Validate redirect origin to prevent open redirect / SSRF
    const rawRedirect = loginRes.headers.get("location") || "/";
    const resolvedRedirect = rawRedirect.startsWith("http")
        ? rawRedirect
        : `${huginnUrl}${rawRedirect}`;
    const redirectOrigin = new URL(resolvedRedirect).origin;
    const expectedOrigin = new URL(huginnUrl).origin;
    if (redirectOrigin !== expectedOrigin) {
        throw new Error(
            `[SEC] Huginn 登录重定向到非预期主机 (${redirectOrigin})，已拒绝 — 可能存在中间人攻击`
        );
    }
    const homeRes = await requestWithFallback(resolvedRedirect, {
        headers: { Cookie: sessionCookie, Accept: "text/html" },
        redirect: "manual",
    });
    const homeHtml = await homeRes.text();
    const homeCookies = extractCookies(homeRes.headers);
    sessionCookie = mergeCookies(sessionCookie, homeCookies);

    const metaCsrf = homeHtml.match(/name="csrf-token"\s+content="([^"]+)"/);
    if (metaCsrf) csrfToken = metaCsrf[1];

    // Extract user_credential for API auth
    const tokenMatch = homeHtml.match(/user_credential[s]?['":\s]+['"]([a-zA-Z0-9_-]+)['"]/);
    if (tokenMatch) userToken = tokenMatch[1];
}

type HeaderLike = {
    get(name: string): string | null;
    getSetCookie?: () => string[];
};

interface ResponseLike {
    status: number;
    ok: boolean;
    headers: HeaderLike;
    text(): Promise<string>;
    json(): Promise<any>;
}

function extractCookies(headers: HeaderLike): string {
    const raw = headers.getSetCookie?.() ?? [];
    return raw.map((c) => c.split(";")[0]).join("; ");
}

function mergeCookies(existing: string, incoming: string): string {
    if (!incoming) return existing;
    if (!existing) return incoming;
    const map = new Map<string, string>();
    for (const part of `${existing}; ${incoming}`.split(";")) {
        const trimmed = part.trim();
        const eq = trimmed.indexOf("=");
        if (eq > 0) map.set(trimmed.slice(0, eq), trimmed);
    }
    return Array.from(map.values()).join("; ");
}

// ─── Lazy login (module-level, visible to huginnFetch) ───

async function ensureLoggedIn(options: { force?: boolean } = {}): Promise<void> {
    if (sessionCookie && userToken) return;

    const now = Date.now();
    if (loginDeferred && !options.force) {
        const nextRetryAt = lastLoginFailureAt + LOGIN_RETRY_BACKOFF_MS;
        if (now < nextRetryAt) {
            throw new Error(
                `Huginn 登录暂缓重试中，将于 ${formatDeferredRetryAt(nextRetryAt)} 后自动重试：${lastLoginError}`
            );
        }
        loginDeferred = false;
        pluginApi?.logger?.info("[huginn] Retrying deferred login after backoff");
    }

    if (loginPromise) return loginPromise;

    loginPromise = (async () => {
        try {
            await login();
            if (loginFailures > 0) {
                pluginApi?.logger?.info(`[huginn] Login recovered after ${loginFailures} failed attempt(s)`);
            }
            loginFailures = 0;
            lastLoginFailureAt = 0;
            lastLoginError = "";
            loginDeferred = false;
        } catch (err: any) {
            clearAuthState();
            loginFailures += 1;
            lastLoginFailureAt = Date.now();
            lastLoginError = err?.message || String(err);

            if (loginFailures >= LOGIN_MAX_FAILURES_BEFORE_DEFER) {
                loginDeferred = true;
                const nextRetryAt = lastLoginFailureAt + LOGIN_RETRY_BACKOFF_MS;
                pluginApi?.logger?.warn(
                    `[huginn] Login deferred after ${loginFailures} failed attempts; next auto-retry after ${formatDeferredRetryAt(nextRetryAt)} — ${lastLoginError}`
                );
            } else {
                pluginApi?.logger?.warn(
                    `[huginn] Login attempt ${loginFailures}/${LOGIN_MAX_FAILURES_BEFORE_DEFER} failed — ${lastLoginError}`
                );
            }
            throw err;
        } finally {
            loginPromise = null;
        }
    })();

    return loginPromise;
}

// ─── Privacy & data scrubbing ───

const SENSITIVE_KEYS = new Set([
    "password", "secret", "token", "api_key", "apikey", "api_secret",
    "access_token", "refresh_token", "private_key", "credential",
    "user_credential", "authenticity_token",
]);

const PII_PATTERNS: [RegExp, string][] = [
    // Email
    [/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, "[EMAIL_REDACTED]"],
    // user_credential in URL query strings
    [/user_credential[s]?=[a-zA-Z0-9_-]+/g, "user_credential=[REDACTED]"],
];

/** Recursively redact sensitive keys from objects returned by Huginn API */
function scrubObject(obj: any): any {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj === "string") return scrubSensitive(obj);
    if (Array.isArray(obj)) return obj.map(scrubObject);
    if (typeof obj === "object") {
        const clean: any = {};
        for (const [key, value] of Object.entries(obj)) {
            if (SENSITIVE_KEYS.has(key.toLowerCase())) {
                clean[key] = "[REDACTED]";
            } else {
                clean[key] = scrubObject(value);
            }
        }
        return clean;
    }
    return obj;
}

/** Scrub sensitive patterns from string output */
function scrubSensitive(text: string): string {
    let result = text;
    for (const [pattern, replacement] of PII_PATTERNS) {
        result = result.replace(pattern, replacement);
    }
    return result;
}

function shouldUseCurlFallback(error: any): boolean {
    return (
        error?.cause?.code === "EHOSTUNREACH" ||
        error?.code === "EHOSTUNREACH" ||
        String(error?.message || error).includes("fetch failed")
    );
}

function createHeaderBag(rawHeaders: string): HeaderLike {
    const values = new Map<string, string[]>();
    for (const line of rawHeaders.split(/\r?\n/)) {
        const idx = line.indexOf(":");
        if (idx <= 0) continue;
        const name = line.slice(0, idx).trim().toLowerCase();
        const value = line.slice(idx + 1).trim();
        const existing = values.get(name) ?? [];
        existing.push(value);
        values.set(name, existing);
    }
    return {
        get(name: string) {
            const found = values.get(name.toLowerCase());
            return found?.[0] ?? null;
        },
        getSetCookie() {
            return values.get("set-cookie") ?? [];
        },
    };
}

async function curlRequest(url: string, options: RequestInit = {}): Promise<ResponseLike> {
    const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "huginn-curl-"));
    const headersPath = path.join(tempDir, "headers.txt");
    const bodyPath = path.join(tempDir, "body.txt");
    const method = options.method || "GET";
    const args = [
        "-sS",
        "--max-time", String(CURL_TIMEOUT_SECONDS),
        "--request", method,
        "--dump-header", headersPath,
        "--output", bodyPath,
        "--write-out", "%{http_code}",
    ];

    const headers = (options.headers as Record<string, string> | undefined) ?? {};
    for (const [name, value] of Object.entries(headers)) {
        args.push("-H", `${name}: ${value}`);
    }
    if (options.body !== undefined) {
        args.push("--data-raw", typeof options.body === "string" ? options.body : String(options.body));
    }
    args.push(url);

    try {
        const { stdout } = await execFileAsync("curl", args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 10 });
        const [rawHeaders, body] = await Promise.all([
            fs.readFile(headersPath, "utf8"),
            fs.readFile(bodyPath, "utf8"),
        ]);
        const status = Number.parseInt(stdout.trim(), 10);
        const headerBlocks = rawHeaders.trim().split(/\r?\n\r?\n/);
        const finalHeaderBlock = headerBlocks[headerBlocks.length - 1] || "";
        const headerLines = finalHeaderBlock.split(/\r?\n/).slice(1).join("\n");
        const headerBag = createHeaderBag(headerLines);
        return {
            status,
            ok: status >= 200 && status < 300,
            headers: headerBag,
            async text() {
                return body;
            },
            async json() {
                return JSON.parse(body);
            },
        };
    } finally {
        await fs.rm(tempDir, { recursive: true, force: true });
    }
}

async function requestWithFallback(url: string, options: RequestInit = {}): Promise<ResponseLike> {
    try {
        return await fetch(url, options);
    } catch (error: any) {
        if (!shouldUseCurlFallback(error)) throw error;
        if (!curlFallbackLogged) {
            curlFallbackLogged = true;
            pluginApi?.logger?.warn("[huginn] Node HTTP failed; using curl fallback for Huginn requests");
        }
        return curlRequest(url, options);
    }
}

// ─── Huginn API fetch with auto-relogin ───

async function huginnFetch(
    path: string,
    options: RequestInit & { retried?: boolean } = {}
): Promise<any> {
    await ensureLoggedIn();
    const { huginnUrl } = getConfig();

    const url = `${huginnUrl}${path}`;
    // Huginn requires user_credential as query param for API auth
    const separator = url.includes("?") ? "&" : "?";
    const authedUrl = userToken ? `${url}${separator}user_credential=${userToken}` : url;

    const headers: Record<string, string> = {
        Accept: "application/json",
        Cookie: sessionCookie,
        ...(options.headers as Record<string, string> || {}),
    };
    if (csrfToken && options.method && options.method !== "GET") {
        headers["X-CSRF-Token"] = csrfToken;
    }
    if (options.body && !headers["Content-Type"]) {
        headers["Content-Type"] = "application/json";
    }

    const res = await requestWithFallback(authedUrl, { ...options, headers, redirect: "manual" });

    // Re-login on auth failure
    if ((res.status === 302 || res.status === 401) && !options.retried) {
        clearAuthState();
        await ensureLoggedIn({ force: true });
        return huginnFetch(path, { ...options, retried: true });
    }

    if (!res.ok && res.status !== 302) {
        const text = await res.text();
        // [SEC] Scrub credentials from error output
        const truncated = text.length > 300 ? text.slice(0, 300) + "…" : text;
        const sanitized = scrubSensitive(truncated);
        throw new Error(`Huginn API error ${res.status}: ${sanitized}`);
    }

    const contentType = res.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
        const raw = await res.text();
        if (!raw.trim()) {
            return { status: res.status, ok: res.ok };
        }
        // [SEC] Scrub sensitive fields before returning to agent
        const data = JSON.parse(raw);
        return scrubObject(data);
    }
    return { status: res.status, message: scrubSensitive(await res.text()) };
}

type AgentWorkingLabel = "Yes" | "No" | "Disabled" | "Unknown";

function parseAgentWorkingLabel(html: string): AgentWorkingLabel {
    const match = html.match(
        /<b>Working:<\/b>[\s\S]*?<(?:(?:a|span)) class="label label-(?:success|warning|danger|default)"[^>]*>([^<]+)<\/(?:a|span)>/i
    );
    const label = match?.[1]?.trim();
    if (label === "Yes" || label === "No" || label === "Disabled") return label;
    return "Unknown";
}

async function huginnFetchHtml(
    path: string,
    options: RequestInit & { retried?: boolean } = {}
): Promise<string> {
    await ensureLoggedIn();
    const { huginnUrl } = getConfig();
    const res = await requestWithFallback(`${huginnUrl}${path}`, {
        ...options,
        headers: {
            Accept: "text/html",
            Cookie: sessionCookie,
            ...(options.headers as Record<string, string> || {}),
        },
        redirect: "manual",
    });

    if ((res.status === 302 || res.status === 401) && !options.retried) {
        clearAuthState();
        await ensureLoggedIn({ force: true });
        return huginnFetchHtml(path, { ...options, retried: true });
    }
    if (!res.ok && res.status !== 302) {
        const text = await res.text();
        const truncated = text.length > 300 ? text.slice(0, 300) + "…" : text;
        throw new Error(`Huginn HTML error ${res.status}: ${scrubSensitive(truncated)}`);
    }
    return res.text();
}

async function enrichAgentStatuses(list: any[]): Promise<any[]> {
    return Promise.all(list.map(async (agent: any) => {
        if (typeof agent.working === "boolean") {
            return {
                ...agent,
                working_label: agent.working ? "Yes" : "No",
            };
        }

        try {
            const html = await huginnFetchHtml(`/agents/${agent.id}`);
            const workingLabel = parseAgentWorkingLabel(html);
            return {
                ...agent,
                working: workingLabel === "Yes" ? true : workingLabel === "No" ? false : null,
                disabled: workingLabel === "Disabled" ? true : !!agent.disabled,
                working_label: workingLabel,
            };
        } catch (error: any) {
            return {
                ...agent,
                working: null,
                working_label: "Unknown",
                status_error: error?.message || String(error),
            };
        }
    }));
}

function hasRecentAgentError(agent: any): boolean {
    if (!agent?.last_error_log_at) return false;
    const ts = Date.parse(agent.last_error_log_at);
    return Number.isFinite(ts) && Date.now() - ts <= RECENT_AGENT_ERROR_WINDOW_MS;
}

function isCriticalPipelineAgent(agent: any): boolean {
    const name = String(agent?.name || "");
    return CRITICAL_AGENT_NAME_PATTERNS.some((pattern) => pattern.test(name));
}

// ─── Pipeline agent IDs (configurable, defaults to Momiji intel pipeline) ───

const PIPELINE_AGENT_IDS = [
    // Feed agents (1-8), DeDup (12), Fetcher (13), Formatter (14),
    // Digest (15), Bridge (10)
    // Discovered at runtime via huginn_list_agents
];

export default function register(api: any) {
    // Store api reference at module scope for getConfig/ensureLoggedIn/huginnFetch
    pluginApi = api;
    api.logger?.info(`[huginn] v${PLUGIN_VERSION} loaded`);

    // ─── Tool 1: 列出所有 agents ───
    api.registerTool({
        name: "huginn_list_agents",
        description:
            "列出 Huginn 中所有 agents 及其状态。返回 ID、名称、类型、调度规则、最近事件数和运行状态。",
        parameters: {
            type: "object",
            properties: {},
        },
        async execute(_toolCallId: string) {
            const agents = await huginnFetch("/agents.json");
            const list = await enrichAgentStatuses(Array.isArray(agents) ? agents : agents.agents || []);
            const summary = list.map((a: any) => ({
                id: a.id,
                name: a.name,
                type: a.type?.replace("Agents::", ""),
                schedule: a.schedule || "manual",
                events_count: a.events_count ?? 0,
                last_check_at: a.last_check_at,
                working: a.working,
                working_label: a.working_label,
                disabled: a.disabled,
            }));
            return { content: [{ type: "text" as const, text: JSON.stringify(summary, null, 2) }] };
        },
    });

    // ─── Tool 2: 获取 agent 详情 ───
    api.registerTool({
        name: "huginn_get_agent",
        description:
            "获取指定 Huginn agent 的完整信息，包括配置选项、sources（上游）、receivers（下游）和运行状态。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID",
                },
            },
            required: ["agent_id"],
        },
        async execute(_toolCallId: string, { agent_id }: { agent_id: number }) {
            const agent = await huginnFetch(`/agents/${agent_id}.json`);
            return { content: [{ type: "text" as const, text: JSON.stringify(agent, null, 2) }] };
        },
    });

    // ─── Tool 3: 手动运行 agent ───
    api.registerTool({
        name: "huginn_run_agent",
        description:
            "手动触发指定 agent 运行一次。适用于需要立即执行的场景（如手动刷新 feed、触发 digest 生成）。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID",
                },
            },
            required: ["agent_id"],
        },
        async execute(_toolCallId: string, { agent_id }: { agent_id: number }) {
            const result = await huginnFetch(`/agents/${agent_id}/run`, {
                method: "POST",
            });
            return {
                content: [{ type: "text" as const, text: JSON.stringify(
                    { success: true, agent_id, message: "Agent run triggered", detail: result },
                    null,
                    2
                ) }],
            };
        },
    });

    // ─── Tool 4: 获取 agent events ───
    api.registerTool({
        name: "huginn_get_agent_events",
        description:
            "获取指定 agent 产生的事件列表。返回最近的 events（含 payload）。用于检查 feed 抓取结果、流水线输出等。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID",
                },
                page: {
                    type: "number",
                    description: "分页页码（默认 1）",
                },
            },
            required: ["agent_id"],
        },
        async execute(_toolCallId: string, { agent_id, page }: { agent_id: number; page?: number }) {
            const p = page || 1;
            const events = await huginnFetch(`/agents/${agent_id}/events.json?page=${p}`);
            return { content: [{ type: "text" as const, text: JSON.stringify(events, null, 2) }] };
        },
    });

    // ─── Tool 5: 获取 agent 日志 ───
    api.registerTool({
        name: "huginn_get_agent_logs",
        description:
            "获取指定 agent 的运行日志。用于调试 agent 错误、检查运行频率和最近活动。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID",
                },
                page: {
                    type: "number",
                    description: "分页页码（默认 1）",
                },
            },
            required: ["agent_id"],
        },
        async execute(_toolCallId: string, { agent_id, page }: { agent_id: number; page?: number }) {
            const p = page || 1;
            const logs = await huginnFetch(`/agents/${agent_id}/logs.json?page=${p}`);
            return { content: [{ type: "text" as const, text: JSON.stringify(logs, null, 2) }] };
        },
    });

    // ─── Tool 6: 注入手动 event ───
    api.registerTool({
        name: "huginn_create_event",
        description:
            "向指定 agent 注入一个手动事件。可用于测试流水线、手动推送情报条目、或触发下游 agent 处理。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID（事件将注入到此 agent）",
                },
                payload: {
                    type: "object",
                    description: "事件 payload（JSON 对象）",
                },
            },
            required: ["agent_id", "payload"],
        },
        async execute(_toolCallId: string, { agent_id, payload }: { agent_id: number; payload: object }) {
            const result = await huginnFetch(`/agents/${agent_id}/events.json`, {
                method: "POST",
                body: JSON.stringify({ event: { payload } }),
            });
            return { content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }] };
        },
    });

    // ─── Tool 7: 更新 agent 配置 ───
    api.registerTool({
        name: "huginn_update_agent",
        description:
            "更新指定 agent 的配置。可修改 options、schedule、sources（上游 agent IDs）、disabled 状态等。",
        parameters: {
            type: "object",
            properties: {
                agent_id: {
                    type: "number",
                    description: "Agent ID",
                },
                options: {
                    type: "object",
                    description: "Agent options（配置参数，如 url、expected_update_period_in_days 等）",
                },
                schedule: {
                    type: "string",
                    description: '调度规则（如 "every_1h", "every_12h", "midnight"）',
                },
                source_ids: {
                    type: "array",
                    items: { type: "number" },
                    description: "上游 agent ID 列表",
                },
                disabled: {
                    type: "boolean",
                    description: "是否禁用",
                },
            },
            required: ["agent_id"],
        },
        async execute(_toolCallId: string, {
            agent_id,
            options,
            schedule,
            source_ids,
            disabled,
        }: {
            agent_id: number;
            options?: object;
            schedule?: string;
            source_ids?: number[];
            disabled?: boolean;
        }) {
            const body: any = { agent: {} };
            if (options !== undefined) body.agent.options = options;
            if (schedule !== undefined) body.agent.schedule = schedule;
            if (source_ids !== undefined) body.agent.source_ids = source_ids;
            if (disabled !== undefined) body.agent.disabled = disabled;

            const result = await huginnFetch(`/agents/${agent_id}.json`, {
                method: "PUT",
                body: JSON.stringify(body),
            });
            return { content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }] };
        },
    });

    // ─── Tool 8: 流水线聚合状态 ───
    api.registerTool({
        name: "huginn_get_pipeline_status",
        description:
            "获取完整情报流水线的聚合状态。列出所有 agents 的名称、类型、事件数、最近检查时间、是否正常工作、是否禁用。快速健康检查。",
        parameters: {
            type: "object",
            properties: {},
        },
        async execute(_toolCallId: string) {
            const agents = await huginnFetch("/agents.json");
            const list = await enrichAgentStatuses(Array.isArray(agents) ? agents : agents.agents || []);

            const pipeline = list.map((a: any) => ({
                id: a.id,
                name: a.name,
                type: a.type?.replace("Agents::", ""),
                events_count: a.events_count ?? 0,
                last_check_at: a.last_check_at,
                last_event_at: a.last_event_at,
                working: a.working,
                working_label: a.working_label,
                disabled: a.disabled,
                last_error_log_at: a.last_error_log_at,
                recent_error: hasRecentAgentError(a),
            }));

            const healthy = pipeline.filter((a) => a.working && !a.disabled).length;
            const disabled = pipeline.filter((a) => a.disabled).length;
            const critical_errors = pipeline.filter(
                (a) => a.working === false && !a.disabled && a.recent_error && isCriticalPipelineAgent(a)
            ).length;
            const errored = pipeline.filter((a) => a.working === false && !a.disabled && a.recent_error).length;
            const degraded = pipeline.filter((a) => a.working === false && !a.disabled && !a.recent_error).length;
            const source_errors = errored - critical_errors;

            return {
                content: [{ type: "text" as const, text: JSON.stringify(
                    {
                        summary: {
                            total: pipeline.length,
                            healthy,
                            disabled,
                            errored,
                            critical_errors,
                            source_errors,
                            degraded,
                        },
                        agents: pipeline,
                    },
                    null,
                    2
                ) }],
            };
        },
    });

    // ─── Tool 9: 情报链路健康检查（含报警） ───
    api.registerTool({
        name: "huginn_health_check",
        description:
            "情报链路端到端健康检查。验证 Huginn 可达性、登录状态、流水线 agent 状态，返回结构化健康报告。任何异常会标记 ALERT。",
        parameters: {
            type: "object",
            properties: {},
        },
        async execute(_toolCallId: string) {
            const checks: { check: string; status: "OK" | "ALERT"; detail: string }[] = [];

            // Check 1: Huginn reachability
            try {
                const { huginnUrl } = getConfig();
                const res = await requestWithFallback(`${huginnUrl}/users/sign_in`, {
                    redirect: "manual",
                    headers: { Accept: "text/html" },
                });
                checks.push({
                    check: "huginn_reachable",
                    status: res.status === 200 || res.status === 302 ? "OK" : "ALERT",
                    detail: `HTTP ${res.status} from ${huginnUrl}`,
                });
            } catch (err: any) {
                checks.push({
                    check: "huginn_reachable",
                    status: "ALERT",
                    detail: `连接失败: ${err.message}`,
                });
            }

            // Check 2: Login / session (non-destructive — reuse existing session)
            try {
                // Only trigger login if no session exists; never clear a working session
                await ensureLoggedIn();
                checks.push({
                    check: "huginn_login",
                    status: "OK",
                    detail: sessionCookie ? "session 有效" : "新登录成功",
                });
            } catch (err: any) {
                checks.push({
                    check: "huginn_login",
                    status: "ALERT",
                    detail: `登录失败: ${err.message}`,
                });
            }

            // Check 3: Pipeline agents status (also validates session liveness)
            try {
                const agents = await huginnFetch("/agents.json");
                const list = await enrichAgentStatuses(Array.isArray(agents) ? agents : agents.agents || []);
                const total = list.length;
                const healthy = list.filter((a: any) => a.working === true && !a.disabled).length;
                const errored = list.filter((a: any) => a.working === false && !a.disabled && hasRecentAgentError(a));
                const degraded = list.filter((a: any) => a.working === false && !a.disabled && !hasRecentAgentError(a));
                const criticalErrors = errored.filter((a: any) => isCriticalPipelineAgent(a));
                const sourceErrors = errored.filter((a: any) => !isCriticalPipelineAgent(a));

                if (criticalErrors.length > 0) {
                    checks.push({
                        check: "pipeline_agents",
                        status: "ALERT",
                        detail:
                            `${criticalErrors.length}/${total} 个核心链路 agent 异常: ` +
                            criticalErrors.map((a: any) => `${a.name}${a.last_error_log_at ? ` (${a.last_error_log_at})` : ""}`).join(", "),
                    });
                } else {
                    checks.push({
                        check: "pipeline_agents",
                        status: "OK",
                        detail: [
                            `${healthy}/${total} agents 核心链路可用`,
                            sourceErrors.length > 0
                                ? `${sourceErrors.length} 个外围情报源近期异常: ${sourceErrors.map((a: any) => a.name).join(", ")}`
                                : "",
                            degraded.length > 0
                                ? `${degraded.length} 个 agent 处于降级/低活跃状态: ${degraded.map((a: any) => a.name).join(", ")}`
                                : "",
                        ].filter(Boolean).join("；"),
                    });
                }
            } catch (err: any) {
                checks.push({
                    check: "pipeline_agents",
                    status: "ALERT",
                    detail: `无法获取 agents: ${err.message}`,
                });
            }

            const hasAlert = checks.some(c => c.status === "ALERT");
            if (hasAlert) {
                pluginApi?.logger?.error(`[huginn] HEALTH CHECK ALERT: ${checks.filter(c => c.status === "ALERT").map(c => c.check).join(", ")}`);
            }

            return {
                content: [{ type: "text" as const, text: JSON.stringify(
                    {
                        overall: hasAlert ? "ALERT" : "OK",
                        timestamp: new Date().toISOString(),
                        checks,
                    },
                    null,
                    2
                ) }],
            };
        },
    });

    api.logger?.info(`[huginn] v${PLUGIN_VERSION} ready — 9 tools registered (incl. health_check)`);
}
