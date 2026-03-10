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

// ─── Session state (module-level, shared across tool calls) ───

let sessionCookie = "";
let csrfToken = "";
let userToken = ""; // Huginn API user_credential token

function getConfig(api: any): { huginnUrl: string; username: string; password: string } {
    const cfg: HuginnConfig = api.config ?? {};
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

async function login(api: any): Promise<void> {
    const { huginnUrl, username, password } = getConfig(api);

    // Step 1: GET /users/sign_in to get CSRF token and session cookie
    const loginPage = await fetch(`${huginnUrl}/users/sign_in`, {
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

    const loginRes = await fetch(`${huginnUrl}/users/sign_in`, {
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
    const homeRes = await fetch(resolvedRedirect, {
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

function extractCookies(headers: Headers): string {
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

// ─── Huginn API fetch with auto-relogin ───

async function huginnFetch(
    api: any,
    path: string,
    options: RequestInit & { retried?: boolean } = {}
): Promise<any> {
    if (!sessionCookie) await login(api);
    const { huginnUrl } = getConfig(api);

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

    const res = await fetch(authedUrl, { ...options, headers, redirect: "manual" });

    // Re-login on auth failure
    if ((res.status === 302 || res.status === 401) && !options.retried) {
        sessionCookie = "";
        csrfToken = "";
        userToken = "";
        await login(api);
        return huginnFetch(api, path, { ...options, retried: true });
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
        // [SEC] Scrub sensitive fields before returning to agent
        const data = await res.json();
        return scrubObject(data);
    }
    return { status: res.status, message: scrubSensitive(await res.text()) };
}

// ─── Pipeline agent IDs (configurable, defaults to Momiji intel pipeline) ───

const PIPELINE_AGENT_IDS = [
    // Feed agents (1-8), DeDup (12), Fetcher (13), Formatter (14),
    // Digest (15), Bridge (10)
    // Discovered at runtime via huginn_list_agents
];

export default function register(api: any) {
    // Eagerly login on plugin load
    login(api).catch((err) => {
        api.logger?.warn(`[huginn] Login deferred — ${err.message}`);
    });

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
            const agents = await huginnFetch(api, "/agents.json");
            const summary = (Array.isArray(agents) ? agents : agents.agents || []).map((a: any) => ({
                id: a.id,
                name: a.name,
                type: a.type?.replace("Agents::", ""),
                schedule: a.schedule || "manual",
                events_count: a.events_count ?? 0,
                last_check_at: a.last_check_at,
                working: a.working,
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
            const agent = await huginnFetch(api, `/agents/${agent_id}.json`);
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
            const result = await huginnFetch(api, `/agents/${agent_id}/run`, {
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
            const events = await huginnFetch(api, `/agents/${agent_id}/events.json?page=${p}`);
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
            const logs = await huginnFetch(api, `/agents/${agent_id}/logs.json?page=${p}`);
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
            const result = await huginnFetch(api, `/agents/${agent_id}/events.json`, {
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

            const result = await huginnFetch(api, `/agents/${agent_id}.json`, {
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
            const agents = await huginnFetch(api, "/agents.json");
            const list: any[] = Array.isArray(agents) ? agents : agents.agents || [];

            const pipeline = list.map((a: any) => ({
                id: a.id,
                name: a.name,
                type: a.type?.replace("Agents::", ""),
                events_count: a.events_count ?? 0,
                last_check_at: a.last_check_at,
                last_event_at: a.last_event_at,
                working: a.working,
                disabled: a.disabled,
            }));

            const healthy = pipeline.filter((a) => a.working && !a.disabled).length;
            const disabled = pipeline.filter((a) => a.disabled).length;
            const errored = pipeline.filter((a) => !a.working && !a.disabled).length;

            return {
                content: [{ type: "text" as const, text: JSON.stringify(
                    {
                        summary: {
                            total: pipeline.length,
                            healthy,
                            disabled,
                            errored,
                        },
                        agents: pipeline,
                    },
                    null,
                    2
                ) }],
            };
        },
    });

    api.logger?.info("[huginn] Plugin loaded — 8 tools registered");
}
