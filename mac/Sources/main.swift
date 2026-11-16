import AppKit

// 今日签 · macOS 菜单栏小工具（MIT）

let app = NSApplication.shared
let args = CommandLine.arguments

if let i = args.firstIndex(of: "--demo") {
    // 演示自动播放：用单独的演示数据，从新用户开始
    Demo.active = true
    Demo.lang = i + 1 < args.count ? args[i + 1] : "zh"
    if let j = args.firstIndex(of: "--demo-out"), j + 1 < args.count { Demo.outDir = URL(fileURLWithPath: args[j + 1]) }
    try? FileManager.default.removeItem(at: Store.fileURL.deletingLastPathComponent())
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
} else if args.contains("--demo-check") {
    // 录制前检查：钥匙串里有没有密钥（只输出有/无），以及你接的是哪家 AI
    Demo.active = true
    print("key=" + (Keychain.load().isEmpty ? "no" : "yes"))
    if let r = DemoDirector.realAI { print("provider=\(r.provider) model=\(r.model)") } else { print("provider=none") }
    exit(0)
} else if args.contains("--reset") {
    // 清零：删掉本机数据与钥匙串里的密钥，下次打开就是新用户
    try? FileManager.default.removeItem(at: Store.fileURL.deletingLastPathComponent())
    Keychain.save("")
    print("已清零：\(Store.fileURL.deletingLastPathComponent().path)")
    exit(0)
} else if args.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
} else if let i = args.firstIndex(of: "--snapshots") {
    let out = i + 1 < args.count ? args[i + 1] : FileManager.default.currentDirectoryPath + "/screens"
    app.setActivationPolicy(.prohibited)
    Task { @MainActor in
        SnapshotRunner.run(outDir: out)
        exit(0)
    }
    app.run()
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
