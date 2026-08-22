import SwiftUI
import AppKit

@main
struct YTDownloaderApp: App {
    var body: some Scene {
        WindowGroup("Rock 专用 YouTube 下载器") {
            ContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct DownloadHistoryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String
    let date: Date
    let folder: String
    let thumbnail: String?
    let quality: String?

    init(id: UUID = UUID(), title: String, url: String, date: Date = Date(), folder: String, thumbnail: String? = nil, quality: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.date = date
        self.folder = folder
        self.thumbnail = thumbnail
        self.quality = quality
    }

    enum CodingKeys: String, CodingKey { case id, title, url, date, folder, thumbnail, quality }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        folder = (try? c.decode(String.self, forKey: .folder)) ?? ""
        thumbnail = try? c.decodeIfPresent(String.self, forKey: .thumbnail)
        quality = try? c.decodeIfPresent(String.self, forKey: .quality)
    }
}

struct VideoInfo {
    var title = ""
    var channel = ""
    var duration = ""
    var thumbnail = ""
}

struct ResumeDownloadTask: Codable, Identifiable {
    let id: UUID
    var url: String
    var savePath: String
    var resolution: String
    var subtitleChoice: String
    var filenameRule: String
    var downloadPlaylist: Bool
    var downloadThumbnail: Bool
    var title: String
    var thumbnail: String
    var duration: String
    var progress: Double
    var outputFile: String?
    var updatedAt: Date

    init(id: UUID = UUID(), url: String, savePath: String, resolution: String, subtitleChoice: String, filenameRule: String, downloadPlaylist: Bool, downloadThumbnail: Bool, title: String = "", thumbnail: String = "", duration: String = "", progress: Double = 0, outputFile: String? = nil, updatedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.savePath = savePath
        self.resolution = resolution
        self.subtitleChoice = subtitleChoice
        self.filenameRule = filenameRule
        self.downloadPlaylist = downloadPlaylist
        self.downloadThumbnail = downloadThumbnail
        self.title = title
        self.thumbnail = thumbnail
        self.duration = duration
        self.progress = progress
        self.outputFile = outputFile
        self.updatedAt = updatedAt
    }
}

struct ContentView: View {
    @State private var urlText = ""
    @State private var resolution = "最高画质"
    @State private var savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/YouTube下载").path
    @State private var status = "准备就绪"
    @State private var logText = ""
    @State private var isRunning = false
    @State private var isReadingInfo = false
    @State private var ytVersion = "检查中…"
    @State private var ffmpegStatus = "检查中…"
    @State private var autoUpdate = false
    @State private var downloadPlaylist = false
    @State private var downloadThumbnail = true
    @State private var subtitleChoice = "不下载字幕"
    @State private var filenameRule = "视频标题"
    @State private var progressValue: Double = 0
    @State private var progressText = "0%"
    @State private var speedText = "—"
    @State private var etaText = "—"
    @State private var info = VideoInfo()
    @State private var history: [DownloadHistoryItem] = []
    @State private var runningTask: Process? = nil
    @State private var capturedTitle = ""
    @State private var capturedThumbnail = ""
    @State private var capturedDuration = ""
    @State private var capturedOutputFile = ""
    @State private var pendingTask: ResumeDownloadTask? = nil
    @State private var pauseRequested = false

    private let toolPATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/Library/Frameworks/Python.framework/Versions/Current/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    private let resolutions = ["最高画质", "4K（2160p）", "2K（1440p）", "1080p", "720p", "480p", "360p", "仅音频 MP3"]
    private let subtitleChoices = ["不下载字幕", "中文", "英文", "中文 + 英文", "全部字幕"]
    private let filenameRules = ["视频标题", "标题 + 视频 ID", "频道 + 标题", "序号 + 标题（播放列表）"]

    // V6.1 统一界面排版规范
    private let uiFontSize: CGFloat = 14
    private let uiSecondaryFontSize: CGFloat = 13
    private let uiSectionTitleSize: CGFloat = 16
    private let uiControlHeight: CGFloat = 34
    private let uiIconWidth: CGFloat = 24
    private let uiLabelWidth: CGFloat = 82
    private let uiControlWidth: CGFloat = 270

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        numberedCard(number: 1, title: "粘贴 YouTube 视频链接") { urlSection }
                        videoInfoCard
                        numberedCard(number: 2, title: "选择下载选项") { optionsSection }
                        numberedCard(number: 3, title: "下载状态") { progressSection }
                    }
                    .padding(18)
                }
                .frame(maxWidth: .infinity)

                Divider()
                historyPanel
                    .frame(width: 330)
            }
            Divider()
            bottomTools
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .font(.system(size: uiFontSize))
        .onAppear {
            ensureSaveDirectory()
            loadHistory()
            loadPendingDownload()
            refreshEnvironment()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.72, blue: 0.98), Color(red: 0.15, green: 0.43, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Circle().fill(.white).frame(width: 38, height: 38)
                Image(systemName: "arrow.down")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Rock 专用 YouTube 下载器")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("粘贴链接 · 读取信息 · 选择规格 · 开始下载")
                    .font(.system(size: uiSecondaryFontSize))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge(title: "yt-dlp", value: ytVersion, ok: ytVersion != "未安装" && ytVersion != "检查中…")
            statusBadge(title: "ffmpeg", value: ffmpegStatus, ok: ffmpegStatus == "已安装")
            Button { refreshEnvironment() } label: { toolIcon("arrow.clockwise", "检查更新") }
                .buttonStyle(.plain)
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: savePath)) } label: { toolIcon("gearshape", "设置") }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func statusBadge(title: String, value: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? .green : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary)
                Text(value).font(.system(size: uiSecondaryFontSize, weight: .semibold)).foregroundStyle(ok ? .green : .primary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toolIcon(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 32)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            Text(title).font(.system(size: uiSecondaryFontSize))
        }
    }

    private func numberedCard<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.system(size: uiSecondaryFontSize, weight: .bold)).foregroundStyle(.blue)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.blue, lineWidth: 1.4))
                Text(title).font(.system(size: uiSectionTitleSize, weight: .semibold))
            }
            content()
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(nsColor: .separatorColor).opacity(0.35)))
    }

    private var urlSection: some View {
        HStack(spacing: 8) {
            TextField("粘贴 YouTube 视频、播放列表或短链接…", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: uiFontSize))
                .onSubmit { readVideoInfo() }
            Button("读取信息") { readVideoInfo() }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || isReadingInfo || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("清空") { urlText = ""; info = VideoInfo() }
                .disabled(urlText.isEmpty)
        }
    }

    private var videoInfoCard: some View {
        Group {
            if !info.title.isEmpty || isReadingInfo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("2").font(.system(size: uiSecondaryFontSize, weight: .bold)).foregroundStyle(.blue)
                            .frame(width: 22, height: 22).overlay(Circle().stroke(.blue, lineWidth: 1.4))
                        Text("视频信息").font(.system(size: uiSectionTitleSize, weight: .semibold))
                    }
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor))
                            if let u = URL(string: info.thumbnail), !info.thumbnail.isEmpty {
                                AsyncImage(url: u) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else if phase.error != nil { Image(systemName: "play.rectangle").font(.system(size: 32)).foregroundStyle(.secondary) }
                                    else { ProgressView() }
                                }
                            } else { Image(systemName: "play.rectangle").font(.system(size: 32)).foregroundStyle(.secondary) }
                        }
                        .frame(width: 255, height: 143).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(info.title.isEmpty ? "正在读取视频信息…" : info.title)
                                .font(.system(size: uiSectionTitleSize, weight: .semibold)).lineLimit(2)
                            if !info.channel.isEmpty { Text(info.channel).font(.system(size: uiFontSize)).foregroundStyle(.secondary) }
                            HStack(spacing: 14) {
                                if !info.duration.isEmpty { Label(info.duration, systemImage: "clock").font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary) }
                                Text(resolution).font(.system(size: uiSecondaryFontSize, weight: .semibold)).foregroundStyle(.green)
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .padding(15)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(nsColor: .separatorColor).opacity(0.35)))
            }
        }
    }

    private var optionsSection: some View {
        HStack(alignment: .top, spacing: 24) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 12) {
                optionGridRow("清晰度", icon: "4k.tv") { picker($resolution, resolutions) }
                optionGridRow("字幕", icon: "captions.bubble") { picker($subtitleChoice, subtitleChoices) }
                optionGridRow("文件名", icon: "textformat") { picker($filenameRule, filenameRules) }
                GridRow(alignment: .center) {
                    Image(systemName: "folder")
                        .frame(width: uiIconWidth, alignment: .center)
                    Text("保存位置")
                        .font(.system(size: uiFontSize, weight: .medium))
                        .frame(width: uiLabelWidth, alignment: .leading)
                    HStack(spacing: 8) {
                        Text(savePath)
                            .font(.system(size: uiFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("选择…") { chooseFolder() }
                            .font(.system(size: uiFontSize))
                            .controlSize(.regular)
                    }
                    .frame(width: uiControlWidth, height: uiControlHeight, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(spacing: 12) {
                switchRow("下载整个播放列表", binding: $downloadPlaylist)
                switchRow("下载前自动更新 yt-dlp", binding: $autoUpdate)
                switchRow("下载封面图片", binding: $downloadThumbnail)
            }
            .frame(width: 260)
        }
    }

    private func picker(_ binding: Binding<String>, _ values: [String]) -> some View {
        Picker("", selection: binding) {
            ForEach(values, id: \.self) { Text($0).font(.system(size: uiFontSize)) }
        }
        .labelsHidden()
        .font(.system(size: uiFontSize))
        .controlSize(.regular)
        .frame(width: uiControlWidth, height: uiControlHeight, alignment: .leading)
    }

    private func optionGridRow<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        GridRow(alignment: .center) {
            Image(systemName: icon)
                .frame(width: uiIconWidth, alignment: .center)
            Text(title)
                .font(.system(size: uiFontSize, weight: .medium))
                .frame(width: uiLabelWidth, alignment: .leading)
            content()
        }
    }

    private func switchRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: uiFontSize, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
        }
        .frame(height: uiControlHeight)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                let displayThumb = capturedThumbnail.isEmpty ? (pendingTask?.thumbnail.isEmpty == false ? pendingTask!.thumbnail : info.thumbnail) : capturedThumbnail
                if let u = URL(string: displayThumb), !displayThumb.isEmpty {
                    AsyncImage(url: u) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                    }
                    .frame(width: 58, height: 36).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTaskTitle)
                        .font(.system(size: uiFontSize, weight: .semibold)).lineLimit(1)
                    Text(status).font(.system(size: uiSecondaryFontSize)).foregroundStyle(isRunning ? .blue : (pendingTask == nil ? .secondary : .orange))
                }
                Spacer()
                if isRunning {
                    Button { pauseDownload() } label: { Label("暂停", systemImage: "pause.fill") }
                        .buttonStyle(.bordered)
                } else if pendingTask != nil {
                    Button { cancelPendingDownload() } label: { Label("取消并删除临时文件", systemImage: "trash") }
                        .buttonStyle(.bordered).foregroundStyle(.red)
                    Button { resumePendingDownload() } label: { Label("继续下载", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    Button { startDownload() } label: {
                        Label("开始下载", systemImage: "arrow.down.to.line.compact")
                            .font(.system(size: uiFontSize, weight: .bold)).frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            ProgressView(value: progressValue, total: 100).progressViewStyle(.linear)
            HStack(spacing: 24) {
                metric("进度", progressText); metric("速度", speedText); metric("剩余时间", etaText)
                if pendingTask != nil && !isRunning {
                    Label(hasPartialFiles(at: pendingTask?.savePath ?? savePath) ? "检测到断点文件，可继续" : "已保存任务，将重新解析后继续", systemImage: "arrow.clockwise.circle")
                        .font(.system(size: uiSecondaryFontSize)).foregroundStyle(.orange)
                }
                Spacer()
            }
            DisclosureGroup("运行日志") {
                ScrollView {
                    Text(logText.isEmpty ? "暂无日志。" : logText)
                        .font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled).padding(.top, 6)
                }.frame(height: 85)
            }.font(.system(size: uiSecondaryFontSize))
        }
    }

    private var displayTaskTitle: String {
        if !capturedTitle.isEmpty { return capturedTitle }
        if let saved = pendingTask, !saved.title.isEmpty { return saved.title }
        if !info.title.isEmpty { return info.title }
        return status
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) { Text(title).font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary); Text(value).font(.system(size: uiSecondaryFontSize, weight: .semibold)) }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("下载历史（\(history.count)）", systemImage: "clock.arrow.circlepath").font(.system(size: uiSectionTitleSize, weight: .semibold))
                Spacer()
                if !history.isEmpty { Button("清空历史") { clearHistory() }.font(.system(size: uiSecondaryFontSize)).buttonStyle(.plain) }
            }
            if history.isEmpty {
                VStack(spacing: 10) {
                    Spacer(); Image(systemName: "tray").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("还没有下载记录").font(.system(size: uiFontSize)).foregroundStyle(.secondary); Spacer()
                }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history) { item in historyRow(item) }
                    }
                }
            }
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: savePath)) } label: {
                Label("打开下载文件夹", systemImage: "folder").frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.55))
    }

    private func historyRow(_ item: DownloadHistoryItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .textBackgroundColor))
                if let thumb = item.thumbnail, let thumbURL = URL(string: thumb), !thumb.isEmpty {
                    AsyncImage(url: thumbURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { Image(systemName: "play.rectangle").foregroundStyle(.secondary) }
                    }
                } else { Image(systemName: "play.rectangle").foregroundStyle(.secondary) }
            }
            .frame(width: 90, height: 52).clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "未命名视频" : item.title)
                    .font(.system(size: uiFontSize, weight: .semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if let quality = item.quality, !quality.isEmpty { Text(quality).font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary) }
                Text(item.date.formatted(date: .numeric, time: .shortened)).font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary)
            }
            Button { NSWorkspace.shared.open(URL(fileURLWithPath: item.folder)) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
            Button { urlText = item.url; readVideoInfo() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bottomTools: some View {
        HStack(spacing: 18) {
            Menu("工具") {
                Button("检查 yt-dlp / ffmpeg") { refreshEnvironment() }
                Button("立即更新 yt-dlp") { updateYTDLP() }
                Button("安装 / 更新 ffmpeg") { installFFmpeg() }
            }
            Button("打开下载文件夹") { NSWorkspace.shared.open(URL(fileURLWithPath: savePath)) }
            Spacer()
            Circle().fill(Color.green).frame(width: 7, height: 7)
            Text("工具状态正常").font(.system(size: uiSecondaryFontSize)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }

    private func ensureSaveDirectory() { try? FileManager.default.createDirectory(atPath: savePath, withIntermediateDirectories: true) }

    private func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url { savePath = url.path }
    }

    private func shell(_ command: String) -> String {
        let task = Process(); let pipe = Pipe(); task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "export PATH=\"\(toolPATH):$HOME/Library/Python/3.13/bin:$HOME/Library/Python/3.12/bin:$HOME/Library/Python/3.11/bin:$HOME/.local/bin:$PATH\"; " + command]
        var env = ProcessInfo.processInfo.environment; env["PATH"] = toolPATH + ":" + (env["PATH"] ?? ""); task.environment = env
        task.standardOutput = pipe; task.standardError = pipe
        do { try task.run(); task.waitUntilExit(); return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" } catch { return "" }
    }

    private func ytdlpCommand() -> String {
        let direct = shell("command -v yt-dlp 2>/dev/null | tail -n 1").trimmingCharacters(in: .whitespacesAndNewlines)
        if direct.hasPrefix("/") { return shellQuote(direct) }
        let python = shell("command -v python3 2>/dev/null | tail -n 1").trimmingCharacters(in: .whitespacesAndNewlines)
        if python.hasPrefix("/") {
            let ok = shell("\(shellQuote(python)) -m yt_dlp --version 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ok.isEmpty { return "\(shellQuote(python)) -m yt_dlp" }
        }
        return ""
    }

    private func refreshEnvironment() {
        DispatchQueue.global(qos: .userInitiated).async {
            let ytdlp = ytdlpCommand(); let y = ytdlp.isEmpty ? "" : shell("\(ytdlp) --version 2>/dev/null")
            let f = shell("command -v ffmpeg >/dev/null 2>&1 && ffmpeg -version 2>/dev/null | head -n 1")
            DispatchQueue.main.async {
                let cleanY = y.trimmingCharacters(in: .whitespacesAndNewlines)
                ytVersion = cleanY.isEmpty ? "未安装" : cleanY.components(separatedBy: .newlines).last ?? cleanY
                ffmpegStatus = f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未安装" : "已安装"
            }
        }
    }

    private func readVideoInfo() {
        let cleanURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanURL.hasPrefix("http://") || cleanURL.hasPrefix("https://") else { status = "网址格式不正确"; return }
        guard !isRunning else { return }
        isReadingInfo = true; status = "正在读取视频信息…"; logText = ""
        let escaped = shellQuote(cleanURL)
        DispatchQueue.global(qos: .userInitiated).async {
            let ytdlp = ytdlpCommand()
            guard !ytdlp.isEmpty else { DispatchQueue.main.async { isReadingInfo = false; status = "没有找到 yt-dlp" }; return }
            let cmd = "\(ytdlp) --no-playlist --skip-download --no-warnings --ignore-no-formats-error --print 'ROCK_TITLE:%(title)s' --print 'ROCK_CHANNEL:%(uploader)s' --print 'ROCK_DURATION:%(duration_string)s' --print 'ROCK_THUMB:%(thumbnail)s' \(escaped) 2>&1"
            let raw = shell(cmd)
            func marked(_ key: String) -> String {
                let prefix = key + ":"
                for line in raw.components(separatedBy: .newlines) where line.hasPrefix(prefix) { return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
                return ""
            }
            let title = marked("ROCK_TITLE"), channel = marked("ROCK_CHANNEL"), duration = marked("ROCK_DURATION"), thumbnail = marked("ROCK_THUMB")
            DispatchQueue.main.async {
                isReadingInfo = false
                if !title.isEmpty { info = VideoInfo(title: title, channel: channel, duration: duration, thumbnail: thumbnail); status = "视频信息读取完成" }
                else { logText = raw; status = "读取失败，但仍可直接下载" }
            }
        }
    }

    private func updateYTDLP() {
        guard !isRunning else { return }
        isRunning = true; status = "正在更新 yt-dlp…"; logText = ""
        let cmd = """
        if command -v brew >/dev/null 2>&1 && brew list yt-dlp >/dev/null 2>&1; then
          brew upgrade yt-dlp || brew reinstall yt-dlp
        elif command -v pip3 >/dev/null 2>&1; then
          pip3 install --upgrade yt-dlp --quiet --break-system-packages 2>/dev/null || pip3 install --upgrade yt-dlp --quiet --user
        elif command -v python3 >/dev/null 2>&1; then
          python3 -m pip install --upgrade yt-dlp --user
        else
          echo '未检测到 Homebrew 或 Python3，无法自动更新。'; exit 1
        fi
        yt-dlp --version 2>/dev/null || python3 -m yt_dlp --version 2>/dev/null
        """
        runStreaming(command: cmd, success: "yt-dlp 更新完成", trackProgress: false) { refreshEnvironment() }
    }

    private func installFFmpeg() {
        guard !isRunning else { return }
        isRunning = true; status = "正在安装 / 更新 ffmpeg…"; logText = ""
        let cmd = """
        if command -v brew >/dev/null 2>&1; then brew install ffmpeg || brew upgrade ffmpeg
        else echo '未检测到 Homebrew。请先安装 Homebrew：https://brew.sh'; exit 1; fi
        """
        runStreaming(command: cmd, success: "ffmpeg 已准备好", trackProgress: false) { refreshEnvironment() }
    }

    private func startDownload(resuming saved: ResumeDownloadTask? = nil) {
        let cleanURL = (saved?.url ?? urlText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanURL.hasPrefix("http://") || cleanURL.hasPrefix("https://") else { status = "网址格式不正确"; return }

        let targetPath = saved?.savePath ?? savePath
        let targetResolution = saved?.resolution ?? resolution
        let targetSubtitle = saved?.subtitleChoice ?? subtitleChoice
        let targetFilenameRule = saved?.filenameRule ?? filenameRule
        let targetPlaylist = saved?.downloadPlaylist ?? downloadPlaylist
        let targetThumbnail = saved?.downloadThumbnail ?? downloadThumbnail

        savePath = targetPath
        resolution = targetResolution
        subtitleChoice = targetSubtitle
        filenameRule = targetFilenameRule
        downloadPlaylist = targetPlaylist
        downloadThumbnail = targetThumbnail
        urlText = cleanURL
        ensureSaveDirectory()

        isRunning = true; pauseRequested = false; status = saved == nil ? "正在下载…" : "正在继续下载…"
        logText = ""
        progressValue = saved?.progress ?? 0
        progressText = String(format: "%.1f%%", progressValue)
        speedText = "—"; etaText = "—"
        capturedTitle = saved?.title ?? info.title
        capturedThumbnail = saved?.thumbnail ?? info.thumbnail
        capturedDuration = saved?.duration ?? info.duration
        capturedOutputFile = saved?.outputFile ?? ""

        let taskSnapshot = ResumeDownloadTask(
            id: saved?.id ?? UUID(), url: cleanURL, savePath: targetPath, resolution: targetResolution,
            subtitleChoice: targetSubtitle, filenameRule: targetFilenameRule, downloadPlaylist: targetPlaylist,
            downloadThumbnail: targetThumbnail, title: capturedTitle, thumbnail: capturedThumbnail, duration: capturedDuration,
            progress: progressValue, outputFile: capturedOutputFile.isEmpty ? nil : capturedOutputFile, updatedAt: Date()
        )
        pendingTask = taskSnapshot
        savePendingDownload()

        let escapedURL = shellQuote(cleanURL), escapedPath = shellQuote(targetPath)
        let playlist = targetPlaylist ? "--yes-playlist" : "--no-playlist"
        let thumbArg = targetThumbnail ? "--write-thumbnail" : ""
        let updater = autoUpdate && saved == nil ? "(yt-dlp -U 2>/dev/null || python3 -m pip install --upgrade yt-dlp --user 2>/dev/null || true)\n" : ""
        let cmd = """
        \(updater)
        YTDLP=$(command -v yt-dlp || true)
        if [ -z "$YTDLP" ]; then
          if python3 -m yt_dlp --version >/dev/null 2>&1; then YTDLP="python3 -m yt_dlp"; else echo '没有找到 yt-dlp。'; exit 1; fi
        fi
        mkdir -p \(escapedPath)
        $YTDLP --continue --part \(formatArguments(for: targetResolution)) \(playlist) \(subtitleArguments(for: targetSubtitle)) \(thumbArg) \
          --print 'before_dl:ROCK_TITLE:%(title)s' \
          --print 'before_dl:ROCK_THUMB:%(thumbnail)s' \
          --print 'before_dl:ROCK_DURATION:%(duration_string)s' \
          --print 'before_dl:ROCK_FILE:%(filename)s' \
          --newline --progress-template 'download:ROCKPROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s' \
          -o \(escapedPath)/\(outputTemplate(for: targetFilenameRule)) \(escapedURL)
        """
        runStreaming(command: cmd, success: "下载完成", trackProgress: true) {
            let finalTitle = capturedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            addHistory(title: finalTitle.isEmpty ? "未命名视频" : finalTitle, url: cleanURL, thumbnail: capturedThumbnail, quality: targetResolution)
            clearPendingDownload()
            NSSound(named: "Glass")?.play()
        }
    }

    private func pauseDownload() {
        guard isRunning, let task = runningTask else { return }
        pauseRequested = true
        status = "正在暂停，保留断点文件…"
        if var saved = pendingTask {
            saved.title = capturedTitle; saved.thumbnail = capturedThumbnail; saved.duration = capturedDuration
            saved.progress = progressValue; saved.outputFile = capturedOutputFile.isEmpty ? saved.outputFile : capturedOutputFile; saved.updatedAt = Date()
            pendingTask = saved; savePendingDownload()
        }
        task.interrupt()
    }

    private func resumePendingDownload() {
        guard !isRunning, let saved = pendingTask else { return }
        startDownload(resuming: saved)
    }

    private func cancelPendingDownload() {
        guard !isRunning, let saved = pendingTask else { return }
        deletePartialFiles(for: saved)
        clearPendingDownload()
        progressValue = 0; progressText = "0%"; speedText = "—"; etaText = "—"
        status = "已取消未完成任务并清理临时文件"
    }

    private func formatArguments(for resolution: String) -> String {
        if resolution == "仅音频 MP3" { return "-x --audio-format mp3 --audio-quality 0" }
        let filter: String
        switch resolution {
        case "4K（2160p）": filter = "bestvideo[height<=2160]+bestaudio/best[height<=2160]"
        case "2K（1440p）": filter = "bestvideo[height<=1440]+bestaudio/best[height<=1440]"
        case "1080p": filter = "bestvideo[height<=1080]+bestaudio/best[height<=1080]"
        case "720p": filter = "bestvideo[height<=720]+bestaudio/best[height<=720]"
        case "480p": filter = "bestvideo[height<=480]+bestaudio/best[height<=480]"
        case "360p": filter = "bestvideo[height<=360]+bestaudio/best[height<=360]"
        default: filter = "bestvideo+bestaudio/best"
        }
        return "-f '\(filter)' --merge-output-format mp4"
    }

    private func subtitleArguments(for subtitleChoice: String) -> String {
        switch subtitleChoice {
        case "中文": return "--write-subs --write-auto-subs --sub-langs 'zh.*,zh-Hans,zh-Hant'"
        case "英文": return "--write-subs --write-auto-subs --sub-langs 'en.*'"
        case "中文 + 英文": return "--write-subs --write-auto-subs --sub-langs 'zh.*,zh-Hans,zh-Hant,en.*'"
        case "全部字幕": return "--write-subs --write-auto-subs --all-subs"
        default: return ""
        }
    }

    private func outputTemplate(for filenameRule: String) -> String {
        switch filenameRule {
        case "标题 + 视频 ID": return "'%(title)s [%(id)s].%(ext)s'"
        case "频道 + 标题": return "'%(uploader)s - %(title)s.%(ext)s'"
        case "序号 + 标题（播放列表）": return "'%(playlist_index)03d - %(title)s.%(ext)s'"
        default: return "'%(title)s.%(ext)s'"
        }
    }

    private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private func parseSpecialLines(_ text: String) {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("ROCK_TITLE:") {
                capturedTitle = String(line.dropFirst("ROCK_TITLE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if info.title.isEmpty { info.title = capturedTitle }
            } else if line.hasPrefix("ROCK_THUMB:") {
                capturedThumbnail = String(line.dropFirst("ROCK_THUMB:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if info.thumbnail.isEmpty { info.thumbnail = capturedThumbnail }
            } else if line.hasPrefix("ROCK_DURATION:") {
                capturedDuration = String(line.dropFirst("ROCK_DURATION:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if info.duration.isEmpty { info.duration = capturedDuration }
            } else if line.hasPrefix("ROCK_FILE:") {
                capturedOutputFile = String(line.dropFirst("ROCK_FILE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.contains("ROCKPROGRESS|"), let range = line.range(of: "ROCKPROGRESS|") {
                let parts = String(line[range.upperBound...]).split(separator: "|", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3 {
                    let p = parts[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                    if let pct = Double(p) { progressValue = min(max(pct, 0), 100); progressText = String(format: "%.1f%%", pct) }
                    speedText = parts[1].isEmpty || parts[1] == "NA" ? "—" : parts[1]
                    etaText = parts[2].isEmpty || parts[2] == "NA" ? "—" : parts[2]
                }
            }
        }
        if var saved = pendingTask {
            saved.title = capturedTitle; saved.thumbnail = capturedThumbnail; saved.duration = capturedDuration
            saved.progress = progressValue; saved.outputFile = capturedOutputFile.isEmpty ? saved.outputFile : capturedOutputFile; saved.updatedAt = Date()
            pendingTask = saved; savePendingDownload()
        }
    }

    private func runStreaming(command: String, success: String, trackProgress: Bool, completion: @escaping () -> Void) {
        let task = Process(); let pipe = Pipe(); task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "export PATH=\"\(toolPATH):$HOME/Library/Python/3.13/bin:$HOME/Library/Python/3.12/bin:$HOME/Library/Python/3.11/bin:$HOME/.local/bin:$PATH\"; " + command]
        var env = ProcessInfo.processInfo.environment; env["PATH"] = toolPATH + ":" + (env["PATH"] ?? ""); task.environment = env
        task.standardOutput = pipe; task.standardError = pipe; runningTask = task

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                if trackProgress { parseSpecialLines(text) }
                let visible = text.components(separatedBy: .newlines).filter {
                    !$0.contains("ROCKPROGRESS|") && !$0.hasPrefix("ROCK_TITLE:") && !$0.hasPrefix("ROCK_THUMB:") && !$0.hasPrefix("ROCK_DURATION:") && !$0.hasPrefix("ROCK_FILE:")
                }.joined(separator: "\n")
                if !visible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    logText += visible + "\n"; if logText.count > 60000 { logText = String(logText.suffix(60000)) }
                }
            }
        }

        task.terminationHandler = { process in
            let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
            let tail = String(data: remaining, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if trackProgress && !tail.isEmpty { parseSpecialLines(tail) }
                pipe.fileHandleForReading.readabilityHandler = nil; runningTask = nil; isRunning = false
                if process.terminationStatus == 0 {
                    if trackProgress { progressValue = 100; progressText = "100%"; etaText = "0s" }
                    status = success; pauseRequested = false; completion()
                } else if pauseRequested {
                    pauseRequested = false
                    status = "已暂停，可继续下载"
                    savePendingDownload()
                } else {
                    status = "操作失败，任务已保留，可稍后继续"
                    savePendingDownload()
                }
            }
        }
        do { try task.run() }
        catch { pipe.fileHandleForReading.readabilityHandler = nil; runningTask = nil; isRunning = false; status = "启动失败"; logText += "\n\(error.localizedDescription)" }
    }

    private func addHistory(title: String, url: String, thumbnail: String = "", quality: String = "") {
        let item = DownloadHistoryItem(title: title, url: url, folder: savePath, thumbnail: thumbnail.isEmpty ? nil : thumbnail, quality: quality)
        history.insert(item, at: 0); if history.count > 30 { history = Array(history.prefix(30)) }; saveHistory()
    }

    private func savePendingDownload() {
        guard let pendingTask, let data = try? JSONEncoder().encode(pendingTask) else { return }
        UserDefaults.standard.set(data, forKey: "rock.download.pending.v6")
    }

    private func loadPendingDownload() {
        guard let data = UserDefaults.standard.data(forKey: "rock.download.pending.v6"),
              let saved = try? JSONDecoder().decode(ResumeDownloadTask.self, from: data) else { return }
        pendingTask = saved
        urlText = saved.url; savePath = saved.savePath; resolution = saved.resolution
        subtitleChoice = saved.subtitleChoice; filenameRule = saved.filenameRule
        downloadPlaylist = saved.downloadPlaylist; downloadThumbnail = saved.downloadThumbnail
        capturedTitle = saved.title; capturedThumbnail = saved.thumbnail; capturedDuration = saved.duration
        capturedOutputFile = saved.outputFile ?? ""
        progressValue = saved.progress; progressText = String(format: "%.1f%%", saved.progress)
        status = hasPartialFiles(at: saved.savePath) ? "发现上次未完成任务，可继续下载" : "发现上次未完成任务，可重新解析后继续"
    }

    private func clearPendingDownload() {
        pendingTask = nil
        UserDefaults.standard.removeObject(forKey: "rock.download.pending.v6")
    }

    private func hasPartialFiles(at path: String) -> Bool {
        guard let e = FileManager.default.enumerator(atPath: path) else { return false }
        while let item = e.nextObject() as? String {
            if item.contains(".part") || item.hasSuffix(".ytdl") { return true }
        }
        return false
    }

    private func deletePartialFiles(for saved: ResumeDownloadTask) {
        let fm = FileManager.default
        var candidates: [String] = []
        if let output = saved.outputFile, !output.isEmpty {
            candidates.append(output + ".part")
            candidates.append(output + ".ytdl")
        }
        for path in candidates where fm.fileExists(atPath: path) { try? fm.removeItem(atPath: path) }

        guard let e = fm.enumerator(atPath: saved.savePath) else { return }
        var removable: [String] = []
        while let item = e.nextObject() as? String {
            let name = (item as NSString).lastPathComponent
            let matchesTitle = !saved.title.isEmpty && name.localizedCaseInsensitiveContains(String(saved.title.prefix(32)))
            let looksPartial = name.contains(".part") || name.hasSuffix(".ytdl")
            if looksPartial && (matchesTitle || saved.outputFile == nil) { removable.append((saved.savePath as NSString).appendingPathComponent(item)) }
        }
        for path in removable { try? fm.removeItem(atPath: path) }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "rock.download.history"), let decoded = try? JSONDecoder().decode([DownloadHistoryItem].self, from: data) else { return }
        history = decoded.map { old in
            if old.title == "YouTube 视频" { return DownloadHistoryItem(id: old.id, title: "旧记录（标题未保存）", url: old.url, date: old.date, folder: old.folder, thumbnail: old.thumbnail, quality: old.quality) }
            return old
        }
    }

    private func saveHistory() { if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: "rock.download.history") } }
    private func clearHistory() { history.removeAll(); UserDefaults.standard.removeObject(forKey: "rock.download.history") }
}
