/**
 * OpenClaw Plugin: Postiz Social Media Integration
 *
 * 为 OpenClaw agents 提供 Postiz 社媒管理能力:
 * - 列出已连接的社媒平台
 * - 创建/调度帖子（支持多平台同步）
 * - 查看已排期帖子
 * - 删除帖子
 * - 上传媒体文件
 * - 获取平台和帖子级分析数据
 * - 触发平台工具（获取 Reddit flair、YouTube playlist 等）
 */

interface PostizConfig {
    apiUrl?: string;
    apiKey?: string;
}

function getConfig(api: any): { apiUrl: string; apiKey: string } {
    const pluginConfig: PostizConfig = api.config ?? {};
    const apiUrl =
        pluginConfig.apiUrl ||
        process.env.POSTIZ_API_URL ||
        "";
    const apiKey =
        pluginConfig.apiKey ||
        process.env.POSTIZ_API_KEY ||
        "";

    if (!apiKey) {
        throw new Error(
            "Postiz API Key 未配置。请设置 POSTIZ_API_KEY 环境变量，或在 openclaw.json 的 plugins.entries.postiz.config.apiKey 中配置"
        );
    }
    if (!apiUrl) {
        throw new Error(
            "Postiz API URL 未配置。请设置 POSTIZ_API_URL 环境变量 (例如: http://your-host:4007/api)，或在 openclaw.json 的 plugins.entries.postiz.config.apiUrl 中配置"
        );
    }

    // 只允许 http/https scheme，防止 file://, javascript: 等协议注入
    if (!/^https?:\/\//i.test(apiUrl)) {
        throw new Error(
            `Postiz API URL 必须以 http:// 或 https:// 开头，当前值: ${apiUrl}`
        );
    }

    // 确保 baseUrl 以 /public/v1 结尾
    const baseUrl = apiUrl.replace(/\/+$/, "");
    const publicUrl = baseUrl.includes("/public/v1")
        ? baseUrl
        : `${baseUrl}/public/v1`;

    return { apiUrl: publicUrl, apiKey };
}

async function postizFetch(
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
        // 截断响应体，防止服务端 echo 敏感字段导致泄漏
        const truncated = text.length > 300 ? text.slice(0, 300) + "…" : text;
        throw new Error(`Postiz API error ${res.status}: ${truncated}`);
    }

    return res.json();
}

export default function register(api: any) {
    // ─── Tool 1: 列出已连接平台 ───
    api.registerTool({
        name: "postiz_list_integrations",
        description:
            "列出 Postiz 中已连接的社媒平台（integrations）。返回平台 ID、名称和提供商信息。在创建帖子前必须先调用此工具获取 integration ID。",
        parameters: {
            type: "object",
            properties: {},
        },
        handler: async () => {
            const data = await postizFetch(api, "/integrations");
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 2: 获取平台设置 ───
    api.registerTool({
        name: "postiz_get_settings",
        description:
            "获取指定社媒平台的设置信息，包括字数限制、必填字段和可用工具。在创建帖子前可调用此工具了解平台要求。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "社媒平台的 integration ID（从 postiz_list_integrations 获取）",
                },
            },
            required: ["integration_id"],
        },
        handler: async ({ integration_id }: { integration_id: string }) => {
            const data = await postizFetch(
                api,
                `/integration-settings/${integration_id}`
            );
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 3: 创建帖子 ───
    api.registerTool({
        name: "postiz_create_post",
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
                    description: "媒体文件 URL 列表（需先通过 postiz_upload_media 上传）",
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
        handler: async ({
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
        }) => {
            const body: any = {
                posts: [{ content, image: media || [] }],
                date,
                type: type || "schedule",
                integrations,
                shortLink: true,
            };
            if (settings) body.settings = settings;

            const data = await postizFetch(api, "/posts", {
                method: "POST",
                body: JSON.stringify(body),
            });
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 4: 查看帖子列表 ───
    api.registerTool({
        name: "postiz_list_posts",
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
        handler: async ({
            start_date,
            end_date,
        }: {
            start_date?: string;
            end_date?: string;
        }) => {
            let path = "/posts";
            const params: string[] = [];
            if (start_date) params.push(`startDate=${encodeURIComponent(start_date)}`);
            if (end_date) params.push(`endDate=${encodeURIComponent(end_date)}`);
            if (params.length) path += `?${params.join("&")}`;

            const data = await postizFetch(api, path);
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 5: 删除帖子 ───
    api.registerTool({
        name: "postiz_delete_post",
        description: "删除指定帖子。",
        parameters: {
            type: "object",
            properties: {
                post_id: {
                    type: "string",
                    description: "帖子 ID（从 postiz_list_posts 获取）",
                },
            },
            required: ["post_id"],
        },
        handler: async ({ post_id }: { post_id: string }) => {
            const data = await postizFetch(api, `/posts/${post_id}`, {
                method: "DELETE",
            });
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 6: 上传媒体 ───
    api.registerTool({
        name: "postiz_upload_media",
        description:
            "上传媒体文件到 Postiz。返回可用于帖子的 URL。⚠️ 重要：TikTok/Instagram/YouTube 等平台必须先通过此工具上传，外部 URL 会被拒绝。",
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
        handler: async ({ file_path }: { file_path: string }) => {
            const fs = await import("fs");
            const path = await import("path");

            // 路径遍历防护：将路径规范化后检查是否为绝对路径，
            // 并拒绝包含 ../  或指向敏感目录的请求
            const resolved = path.resolve(file_path);
            const BLOCKED = ["/etc", "/var", "/root", "/proc", "/sys"];
            if (BLOCKED.some((dir) => resolved.startsWith(dir))) {
                throw new Error(`拒绝访问受限路径: ${resolved}`);
            }
            // 路径必须是绝对路径
            if (!path.isAbsolute(resolved)) {
                throw new Error("file_path 必须是绝对路径");
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
                throw new Error(`Upload failed: ${res.status} ${await res.text()}`);
            }

            const data = await res.json();
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 7: 平台分析 ───
    api.registerTool({
        name: "postiz_get_analytics",
        description:
            "获取指定社媒平台的分析数据（粉丝数、曝光量、互动率等）。",
        parameters: {
            type: "object",
            properties: {
                integration_id: {
                    type: "string",
                    description: "社媒平台 integration ID",
                },
                days: {
                    type: "number",
                    description: "回溯天数（默认 7）",
                },
            },
            required: ["integration_id"],
        },
        handler: async ({
            integration_id,
            days,
        }: {
            integration_id: string;
            days?: number;
        }) => {
            const d = days || 7;
            const data = await postizFetch(
                api,
                `/analytics/${integration_id}?days=${d}`
            );
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 8: 帖子分析 ───
    api.registerTool({
        name: "postiz_get_post_analytics",
        description:
            "获取单个帖子的分析数据（点赞、评论、分享、曝光等）。如果返回 {missing: true}，需要调用 postiz CLI 的 posts:missing 和 posts:connect 修复。",
        parameters: {
            type: "object",
            properties: {
                post_id: {
                    type: "string",
                    description: "帖子 ID",
                },
                days: {
                    type: "number",
                    description: "回溯天数（默认 7）",
                },
            },
            required: ["post_id"],
        },
        handler: async ({ post_id, days }: { post_id: string; days?: number }) => {
            const d = days || 7;
            const data = await postizFetch(
                api,
                `/analytics/post/${post_id}?days=${d}`
            );
            return { content: JSON.stringify(data, null, 2) };
        },
    });

    // ─── Tool 9: 触发平台工具 ───
    api.registerTool({
        name: "postiz_trigger_tool",
        description:
            "触发平台特定工具，获取动态数据（如 Reddit flair、YouTube playlist、LinkedIn company 列表等）。先用 postiz_get_settings 查看可用工具列表。",
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
        handler: async ({
            integration_id,
            method,
            data,
        }: {
            integration_id: string;
            method: string;
            data?: object;
        }) => {
            // NOTE: body 已通过 postizFetch body 参数传递，此处无需单独序列化
            const result = await postizFetch(
                api,
                `/integration-trigger/${integration_id}`,
                {
                    method: "POST",
                    body: JSON.stringify({ method, data: data || {} }),
                }
            );
            return { content: JSON.stringify(result, null, 2) };
        },
    });

    api.logger?.info("[postiz] Plugin loaded — 9 tools registered");
}
