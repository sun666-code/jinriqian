import Foundation

// MARK: - AI 一键接入：选服务商 → 粘贴密钥 → 连接（自动拉模型、自动选、自动测试）
// 这里只放各家公开的接口地址，不含任何密钥。模型名以接口实时返回的列表为准，
// 预设里的 model 只在拉不到列表时兜底。

struct AIPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let base: String
    let model: String          // 兜底模型
    let prefer: [String]       // 自动选模型时的偏好关键词（越靠前越优先）
    let keyURL: String         // 去哪里拿密钥
}

enum AIPresets {
    static let all: [AIPreset] = [
        AIPreset(id: "deepseek", name: "DeepSeek", base: "https://api.deepseek.com", model: "deepseek-chat",
                 prefer: ["flash", "chat", "v4", "v3"], keyURL: "https://platform.deepseek.com/api_keys"),
        AIPreset(id: "kimi", name: "Kimi", base: "https://api.moonshot.cn/v1", model: "kimi-latest",
                 prefer: ["kimi-latest", "kimi-k2", "kimi", "moonshot-v1-8k"], keyURL: "https://platform.moonshot.cn/console/api-keys"),
        AIPreset(id: "qwen", name: "通义千问", base: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus",
                 prefer: ["qwen-plus", "qwen-turbo", "qwen-max", "qwen"], keyURL: "https://bailian.console.aliyun.com/?apiKey=1"),
        AIPreset(id: "glm", name: "智谱 GLM", base: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash",
                 prefer: ["flash", "air", "glm-4", "glm"], keyURL: "https://open.bigmodel.cn/usercenter/apikeys"),
        AIPreset(id: "silicon", name: "硅基流动", base: "https://api.siliconflow.cn/v1", model: "deepseek-ai/DeepSeek-V3",
                 prefer: ["deepseek-v3", "deepseek", "qwen"], keyURL: "https://cloud.siliconflow.cn/account/ak"),
        AIPreset(id: "openai", name: "OpenAI", base: "https://api.openai.com/v1", model: "gpt-4o-mini",
                 prefer: ["mini", "gpt-4o", "gpt"], keyURL: "https://platform.openai.com/api-keys"),
        AIPreset(id: "custom", name: "自定义", base: "", model: "", prefer: [], keyURL: ""),
    ]

    static func find(_ id: String) -> AIPreset? { all.first { $0.id == id } }

    /// 当前用的是哪家：优先看保存的 id，其次按地址猜，都没有就默认 DeepSeek
    static func current(_ s: Settings) -> AIPreset {
        if let p = find(s.aiProvider) { return p }
        let e = s.aiEndpoint.lowercased()
        if !e.isEmpty {
            for p in all where !p.base.isEmpty {
                if let host = URL(string: p.base)?.host, e.contains(host) { return p }
            }
            return find("custom")!
        }
        return all[0]
    }

    /// 去掉向量、语音、绘图之类不能聊天的模型
    static func chatModels(_ list: [String]) -> [String] {
        let bad = ["embed", "rerank", "tts", "whisper", "dall", "moderation", "speech", "audio", "image", "ocr", "bge", "realtime", "transcribe"]
        return list.filter { m in let l = m.lowercased(); return !bad.contains { l.contains($0) } }
    }

    /// 自动挑一个模型：按偏好关键词，其次兜底模型，最后第一个
    static func pick(_ list: [String], preset: AIPreset) -> String? {
        let ms = chatModels(list)
        for k in preset.prefer {
            if let hit = ms.first(where: { $0.lowercased().contains(k) && !$0.lowercased().contains("reason") }) { return hit }
        }
        if ms.contains(preset.model) { return preset.model }
        return ms.first
    }
}
