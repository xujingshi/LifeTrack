import SwiftUI
import Speech
import AVFoundation

// MARK: - 咻视图（快速记录）
struct QuickNoteView: View {
    @State private var notes: [QuickNote] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isRecording = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var editingNote: QuickNote?
    @State private var editText = ""
    @State private var searchText = ""
    @State private var isSearching = false

    @StateObject private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 笔记列表
                if notes.isEmpty && !isLoading && searchText.isEmpty {
                    emptyStateView
                } else if notes.isEmpty && !isLoading && !searchText.isEmpty {
                    noResultsView
                } else {
                    noteListView
                }

                Divider()

                // 输入区域
                inputAreaView
            }
            .navigationTitle("咻 ⚡")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "搜索笔记...")
            .onChange(of: searchText) { _ in
                Task {
                    await loadNotes()
                }
            }
            .task {
                await loadNotes()
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $editingNote) { note in
                EditQuickNoteSheet(
                    note: note,
                    onSave: { updatedNote in
                        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
                            notes[index] = updatedNote
                        }
                        editingNote = nil
                    },
                    onCancel: {
                        editingNote = nil
                    }
                )
            }
        }
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))

            Text("有什么想法？咻一下！")
                .font(.headline)
                .foregroundColor(.gray)

            Text("点击下方麦克风语音输入\n或直接打字记录")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - 无搜索结果视图
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))

            Text("没有找到相关笔记")
                .font(.headline)
                .foregroundColor(.gray)

            Text("试试其他关键词")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))

            Spacer()
        }
        .padding()
    }

    // MARK: - 笔记列表视图
    private var noteListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notes) { note in
                    QuickNoteRow(
                        note: note,
                        onEdit: {
                            editingNote = note
                        },
                        onDelete: {
                            await deleteNote(id: note.id)
                        }
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await loadNotes()
        }
    }

    // MARK: - 输入区域视图
    private var inputAreaView: some View {
        VStack(spacing: 12) {
            // 语音识别文本显示
            if isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("正在聆听...")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                // 文本输入框
                TextField("记录你的想法...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .onChange(of: speechRecognizer.transcript) { newValue in
                        if isRecording {
                            inputText = newValue
                        }
                    }

                // 语音按钮
                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(isRecording ? .red : .orange)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isRecording)
                }

                // 发送按钮
                Button {
                    Task {
                        await sendNote()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 方法
    private func loadNotes() async {
        isLoading = true
        do {
            let response = try await QuickNoteService.shared.getList(keyword: searchText)
            notes = response.list
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            showError = true
        }
        isLoading = false
    }

    private func sendNote() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let wasRecording = isRecording
        if isRecording {
            stopRecording()
        }

        do {
            let note = try await QuickNoteService.shared.create(content: content, isVoice: wasRecording)
            notes.insert(note, at: 0)
            inputText = ""
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteNote(id: Int) async {
        do {
            try await QuickNoteService.shared.delete(id: id)
            notes.removeAll { $0.id == id }
        } catch {
            errorMessage = "删除失败: \(error.localizedDescription)"
            showError = true
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        speechRecognizer.resetTranscript()
        speechRecognizer.startTranscribing()
        isRecording = true
    }

    private func stopRecording() {
        speechRecognizer.stopTranscribing()
        isRecording = false
    }
}

// MARK: - 快速笔记行视图
struct QuickNoteRow: View {
    let note: QuickNote
    let onEdit: () -> Void
    let onDelete: () async -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if note.isVoice {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Text(note.formattedTime)
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(note.content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onEdit()
        }
        .confirmationDialog("确定删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task {
                    await onDelete()
                }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - 编辑快速笔记 Sheet
struct EditQuickNoteSheet: View {
    let note: QuickNote
    let onSave: (QuickNote) -> Void
    let onCancel: () -> Void

    @State private var editText: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $editText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()

                Spacer()
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            editText = note.content
        }
    }

    private func saveNote() async {
        let content = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSaving = true
        do {
            let updatedNote = try await QuickNoteService.shared.update(id: note.id, content: content)
            onSave(updatedNote)
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
        }
        isSaving = false
    }
}

// MARK: - 语音识别器
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

    func startTranscribing() {
        // 请求权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.startRecording()
                default:
                    print("语音识别权限未授权")
                }
            }
        }
    }

    private func startRecording() {
        // 重置
        recognitionTask?.cancel()
        recognitionTask = nil

        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("音频会话配置失败: \(error)")
            return
        }

        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            print("语音识别不可用")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self?.stopEngine()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("音频引擎启动失败: \(error)")
        }
    }

    func stopTranscribing() {
        recognitionRequest?.endAudio()
        stopEngine()
    }

    private func stopEngine() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    func resetTranscript() {
        transcript = ""
    }
}

#Preview {
    QuickNoteView()
}
