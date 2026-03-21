/**
 * OpenClaw Plugin: XPoz Social Media Integration
 *
 * 为 OpenClaw agents 提供 XPoz 社媒管理能力:
 * - 列出已连接的社媒平台
 * - 创建/调度帖子（支持多平台同步）
 * - 查看已排期帖子
 * - 删除帖子
 * - 上传媒体文件（本地或远程 URL）
 * - 获取平台和帖子级分析数据
 * - 触发平台工具（获取 Reddit flair、YouTube playlist 等）
 * - 连接/断开社媒渠道
 * - 查看通知
 * - 查找调度空闲时间
 * - 检查连接状态
 */

interface XPozConfig {
    apiUrl?: string;
    apiKey?: string;
}

function getConfig(api: any): { apiUrl: string; apiKey: string } {
    const pluginConfig: XPozConfig = api.config ?? {};
    const apiUrl =
        pluginConfig.apiUrl ||
        process.env.XPOZ_API_URL ||
        process.env.POSTIZ_API_URL ||  // backward compat
        "";
    const apiKey =
        pluginConfig.apiKey ||
        process.env.XPOZ_API_KEY ||
        process.env.POSTIZ_API_KEY ||  // backward compat
        "";

    if (!apiKey) {
        throw new Error(
            "XPoz API Key 未配置。请设置 XPOZ_API_KEY 环境变量，或在 openclaw.json 的 plugins.entries.xpoz.config.apiKey 中配置"
        );
    }
    if (!apiUrl) {
        throw new Error(
            "XPoz API URL 未配置。请设置 XPOZ_API_URL 环境变量 (例如: http://your-host:4007/api)，或在 openclaw.json 的 plugins.entries.xpoz.config.apiUrl 中配置"
        );
    }

    // 只允许 http/https scheme，防止 file://, javascript: 等协议注入
    if (!/^https?:\/\//i.test(apiUrl)) {
        throw new Error(
            `XPoz API URL 必须以 http:// 或 https:// 开头，当前值: ${apiUrl}`
        );
    }

    // 确保 baseUrl 以 /public/v1 结尾
    const baseUrl = apiUrl.replace(/\/+$/, "");
    const publicUrl = baseUrl.includes("/public/v1")
        ? baseUrl
        : `${baseUrl}/public/v1`;

    return { apiUrl: publicUrl, apiKey };
}

async function xpozFetch(
    api: any,
    path: string,
    options: RequestInit = {}
): Promise<any> {
    const { apiUrl, apiKey } = getConfig(api);
    const url = `${apiUrl}${path}`;

    const res = await fetch(url, {
        ...options,
        headers: {
            "Content-Type": "application/json",
            Authorization: apiKey,
            ...(options.headers || {}),
        },
    });

    if (!res.ok) {
        const text = await res.text();
        // [SEC] Truncate and scrub sensitive patterns from error response
        const truncated = text.length > 300 ? text.slice(0, 300) + "…" : text;
        const sanitized = truncated
            .replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, "[EMAIL_REDACTED]")
            .replace(/(?:api[_-]?key|token|secret|password|credential)['"\:\s]*['"]?[a-zA-Z0-9_-]{8,}['"]?/gi, "[CREDENTIAL_REDACTED]");
        throw new Error(`XPoz API error ${res.status}: ${sanitized}`);
    }

    return res.json();
}

export default function register(api: any) {
    // ─── Tool 1: 列出已连接平台 ───
    api.registerTool({
        name: "xpoz_list_integrations",
        description:
            "列出 XPoz 中已连接的社媒平台（integrations）。返回平台 ID、名称和提供商信息。在创建帖子前必须先调用此工具获取 integration ID。",
        parameters: {
            type: "object",
            properties: {},
        },
        async execute(_toolCallId: string) {
            const data = await xpozFetch(api, "/integrations");
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 2: 获取平台设置 ───
    api.registerTool({
        name: "xpoz_get_settings",
        description:
            "获取指定社媒平台的设置信息，包括字数限制、必填字段和可用工具。在创建帖子前可调用此工具了解平台要求。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "社媒平台的 integration ID（从 xpoz_list_integrations 获取）",
                },
            },
            required: ["integration_id"],
        },
        async execute(_toolCallId: string, { integration_id }: { integration_id: string }) {
            const data = await xpozFetch(
                api,
                `/integration-settings/${integration_id}`
            );
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 3: 创建帖子 ───
    api.registerTool({
        name: "xpoz_create_post",
        description:
            "在指定社媒平台创建/调度帖子。支持多平台同步发布、附加媒体、评论/线程。日期格式必须为 ISO 8601。",
        parameters: {
            type: "object",
            properties: {
                content: {
                    type: "string",
                    description: "帖子正文内容",
                },
                date: {
                    type: "string",
                    description: '发布时间 (ISO 8601), 例如 "2026-03-10T09:00:00Z"',
                },
                integrations: {
                    type: "array",
                    items: { type: "string" },
                    description: "目标平台 integration ID 列表",
                },
                media: {
                    type: "array",
                    items: { type: "string" },
                    description: "媒体文件 URL 列表（需先通过 xpoz_upload_media 或 xpoz_upload_from_url 上传）",
                },
                type: {
                    type: "string",
                    enum: ["schedule", "draft"],
                    description: '帖子类型: "schedule"（定时发布）或 "draft"（草稿），默认 schedule',
                },
                settings: {
                    type: "object",
                    description: "平台特定设置（如 Reddit 的 subreddit、YouTube 的 title 等）",
                },
            },
            required: ["content", "date", "integrations"],
        },
        async execute(_toolCallId: string, {
            content,
            date,
            integrations,
            media,
            type,
            settings,
        }: {
            content: string;
            date: string;
            integrations: string[];
            media?: string[];
            type?: string;
            settings?: object;
        }) {
            const body: any = {
                posts: [{ content, image: media || [] }],
                date,
                type: type || "schedule",
                integrations,
                shortLink: true,
            };
            if (settings) body.settings = settings;

            const data = await xpozFetch(api, "/posts", {
                method: "POST",
                body: JSON.stringify(body),
            });
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 4: 查看帖子列表 ───
    api.registerTool({
        name: "xpoz_list_posts",
        description:
            "查看已调度的帖子列表。默认显示最近 30 天到未来 30 天的帖子。",
        parameters: {
            type: "object",
            properties: {
                start_date: {
                    type: "string",
                    description: "起始日期 (ISO 8601)",
                },
                end_date: {
                    type: "string",
                    description: "结束日期 (ISO 8601)",
                },
            },
        },
        async execute(_toolCallId: string, {
            start_date,
            end_date,
        }: {
            start_date?: string;
            end_date?: string;
        }) {
            let path = "/posts";
            const params: string[] = [];
            if (start_date) params.push(`startDate=${encodeURIComponent(start_date)}`);
            if (end_date) params.push(`endDate=${encodeURIComponent(end_date)}`);
            if (params.length) path += `?${params.join("&")}`;

            const data = await xpozFetch(api, path);
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 5: 删除帖子 ───
    api.registerTool({
        name: "xpoz_delete_post",
        description: "删除指定帖子。",
        parameters: {
            type: "object",
            properties: {
                post_id: {
                    type: "string",
                    description: "帖子 ID（从 xpoz_list_posts 获取）",
                },
            },
            required: ["post_id"],
        },
        async execute(_toolCallId: string, { post_id }: { post_id: string }) {
            const data = await xpozFetch(api, `/posts/${post_id}`, {
                method: "DELETE",
            });
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 6: 上传媒体（本地文件）───
    api.registerTool({
        name: "xpoz_upload_media",
        description:
            "上传本地媒体文件到 XPoz。返回可用于帖子的 URL。⚠️ 重要：TikTok/Instagram/YouTube 等平台必须先通过此工具上传，外部 URL 会被拒绝。",
        parameters: {
            type: "object",
            properties: {
                file_path: {
                    type: "string",
                    description: "本地文件路径",
                },
            },
            required: ["file_path"],
        },
        async execute(_toolCallId: string, { file_path }: { file_path: string }) {
            const fs = await import("fs");
            const path = await import("path");

            // [SEC] Path traversal defense
            const resolved = path.resolve(file_path);
            const homeDir = process.env.HOME || process.env.USERPROFILE || "/";
            const ALLOWED_ROOTS = [
                path.resolve(homeDir),
                "/tmp",
            ];
            const inAllowedRoot = ALLOWED_ROOTS.some(
                (root) => resolved.startsWith(root + path.sep) || resolved === root
            );
            if (!inAllowedRoot) {
                throw new Error("拒绝上传: 文件路径不在允许范围内");
            }

            const SENSITIVE_PATTERNS = [
                "/.ssh/", "/.gnupg/", "/.aws/", "/.kube/", "/.config/gcloud/",
                "/.docker/", "/.npmrc", "/.netrc", "/.env", "/credentials",
                "/.openclaw/openclaw.env", "/id_rsa", "/id_ed25519",
                "/.bash_history", "/.zsh_history",
            ];
            const normalizedPath = resolved.replace(/\\/g, "/");
            if (SENSITIVE_PATTERNS.some((p) => normalizedPath.includes(p))) {
                throw new Error("拒绝上传: 路径包含敏感文件或目录");
            }

            const relToHome = path.relative(path.resolve(homeDir), resolved);
            if (relToHome.startsWith(".") && !relToHome.includes(path.sep)) {
                throw new Error("拒绝上传: 不允许上传 home 目录下的隐藏配置文件");
            }

            if (!fs.existsSync(resolved)) {
                throw new Error(`文件不存在: ${resolved}`);
            }

            const { apiUrl, apiKey } = getConfig(api);
            const fileName = path.basename(resolved);
            const fileBuffer = fs.readFileSync(resolved);
            const blob = new Blob([fileBuffer]);

            const formData = new FormData();
            formData.append("file", blob, fileName);

            const res = await fetch(`${apiUrl}/upload`, {
                method: "POST",
                headers: {
                    Authorization: apiKey,
                },
                body: formData,
            });

            if (!res.ok) {
                const errText = await res.text();
                const truncErr = errText.length > 300 ? errText.slice(0, 300) + "…" : errText;
                throw new Error(`Upload failed: ${res.status} ${truncErr}`);
            }

            const data = await res.json();
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 7: 从 URL 上传媒体 ───  [NEW]
    api.registerTool({
        name: "xpoz_upload_from_url",
        description:
            "从远程 URL 下载并上传媒体文件到 XPoz。无需本地文件，直接提供远程图片/视频 URL 即可。返回可用于帖子的 XPoz 托管 URL。",
        parameters: {
            type: "object",
            properties: {
                url: {
                    type: "string",
                    description: "远程媒体文件 URL（如 https://example.com/image.jpg）",
                },
            },
            required: ["url"],
        },
        async execute(_toolCallId: string, { url }: { url: string }) {
            const data = await xpozFetch(api, "/upload-from-url", {
                method: "POST",
                body: JSON.stringify({ url }),
            });
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 8: 平台分析 ───
    api.registerTool({
        name: "xpoz_get_analytics",
        description:
            "获取指定社媒平台的分析数据（粉丝数、曝光量、互动率等）。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "社媒平台 integration ID",
                },
                date: {
                    type: "string",
                    description: "起始日期 (ISO 8601)，默认 7 天前",
                },
            },
            required: ["integration_id"],
        },
        async execute(_toolCallId: string, {
            integration_id,
            date,
        }: {
            integration_id: string;
            date?: string;
        }) {
            const query = date ? `?date=${encodeURIComponent(date)}` : "";
            const data = await xpozFetch(
                api,
                `/analytics/${integration_id}${query}`
            );
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 9: 帖子分析 ───
    api.registerTool({
        name: "xpoz_get_post_analytics",
        description:
            "获取单个帖子的分析数据（点赞、评论、分享、曝光等）。",
        parameters: {
            type: "object",
            properties: {
                post_id: {
                    type: "string",
                    description: "帖子 ID",
                },
                date: {
                    type: "string",
                    description: "日期 (ISO 8601)",
                },
            },
            required: ["post_id"],
        },
        async execute(_toolCallId: string, { post_id, date }: { post_id: string; date?: string }) {
            const query = date ? `?date=${encodeURIComponent(date)}` : "";
            const data = await xpozFetch(
                api,
                `/analytics/post/${post_id}${query}`
            );
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 10: 触发平台工具 ───
    api.registerTool({
        name: "xpoz_trigger_tool",
        description:
            "触发平台特定工具，获取动态数据（如 Reddit flair、YouTube playlist、LinkedIn company 列表等）。先用 xpoz_get_settings 查看可用工具列表。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "社媒平台 integration ID",
                },
                method: {
                    type: "string",
                    description: '工具方法名（如 "getFlairs", "getPlaylists", "getCompanies"）',
                },
                data: {
                    type: "object",
                    description: '方法参数（如 {"subreddit": "programming"}）',
                },
            },
            required: ["integration_id", "method"],
        },
        async execute(_toolCallId: string, {
            integration_id,
            method,
            data,
        }: {
            integration_id: string;
            method: string;
            data?: object;
        }) {
            const result = await xpozFetch(
                api,
                `/integration-trigger/${integration_id}`,
                {
                    method: "POST",
                    body: JSON.stringify({ methodName: method, data: data || {} }),
                }
            );
            return { content: [{ type: "text" as const, text: JSON.stringify(result, null, 2) }] };
        },
    });

    // ─── Tool 11: 连接渠道 ───  [NEW]
    api.registerTool({
        name: "xpoz_connect_channel",
        description:
            "生成 OAuth 授权 URL 以连接新的社媒渠道。支持的 provider: x, linkedin, facebook, instagram, youtube, tiktok, reddit, threads, bluesky, mastodon, pinterest, discord, telegram 等。返回一个 URL，用户需在浏览器中打开完成授权。",
        parameters: {
            type: "object",
            properties: {
                provider: {
                    type: "string",
                    description: '社媒平台 provider 标识符（如 "x", "linkedin", "facebook", "youtube"）',
                },
                refresh: {
                    type: "string",
                    description: "如需重新连接已有渠道，传入该 integration ID",
                },
            },
            required: ["provider"],
        },
        async execute(_toolCallId: string, { provider, refresh }: { provider: string; refresh?: string }) {
            const query = refresh ? `?refresh=${encodeURIComponent(refresh)}` : "";
            const data = await xpozFetch(api, `/social/${provider}${query}`);
            return {
                content: [{
                    type: "text" as const,
                    text: `🔗 请在浏览器中打开以下 URL 完成授权:\n\n${data.url}\n\n授权完成后，渠道将自动出现在 integrations 列表中。`,
                }],
            };
        },
    });

    // ─── Tool 12: 断开渠道 ───  [NEW]
    api.registerTool({
        name: "xpoz_disconnect_channel",
        description:
            "断开/删除指定的社媒渠道。该操作会同时删除该渠道的所有待发布帖子。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "要断开的渠道 integration ID",
                },
            },
            required: ["integration_id"],
        },
        async execute(_toolCallId: string, { integration_id }: { integration_id: string }) {
            const data = await xpozFetch(api, `/integrations/${integration_id}`, {
                method: "DELETE",
            });
            return { content: [{ type: "text" as const, text: `✅ 渠道 ${integration_id} 已断开。\n${JSON.stringify(data, null, 2)}` }] };
        },
    });

    // ─── Tool 13: 查看通知 ───  [NEW]
    api.registerTool({
        name: "xpoz_list_notifications",
        description:
            "查看 XPoz 通知列表（发布成功/失败通知、系统消息等）。",
        parameters: {
            type: "object",
            properties: {
                page: {
                    type: "number",
                    description: "页码（默认 0）",
                },
            },
        },
        async execute(_toolCallId: string, { page }: { page?: number }) {
            const p = page || 0;
            const data = await xpozFetch(api, `/notifications?page=${p}`);
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 14: 查找调度空闲时间 ───  [NEW]
    api.registerTool({
        name: "xpoz_find_slot",
        description:
            "查找下一个可用的调度时间段。用于自动排期时避免与已有帖子冲突。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "可选：指定渠道的 integration ID，获取该渠道的空闲时间",
                },
            },
        },
        async execute(_toolCallId: string, { integration_id }: { integration_id?: string }) {
            const id = integration_id || "all";
            const data = await xpozFetch(api, `/find-slot/${id}`);
            return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
        },
    });

    // ─── Tool 15: 检查连接状态 ───  [NEW]
    api.registerTool({
        name: "xpoz_status",
        description:
            "检查 XPoz API 连接状态。用于验证配置是否正确、服务是否在线。",
        parameters: {
            type: "object",
            properties: {},
        },
        async execute(_toolCallId: string) {
            const data = await xpozFetch(api, "/is-connected");
            return {
                content: [{
                    type: "text" as const,
                    text: data.connected
                        ? "✅ XPoz API 连接正常"
                        : "❌ XPoz API 连接异常",
                }],
            };
        },
    });

    api.logger?.info("[xpoz] Plugin loaded — 15 tools registered");
}
