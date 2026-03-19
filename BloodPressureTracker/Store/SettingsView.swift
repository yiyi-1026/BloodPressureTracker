import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @State private var isImporting = false
    @State private var showImportAlert = false
    @State private var importResult: (imported: Int, skipped: Int)?
    @State private var errorMessage: String?
    @State private var showHealthKitUnavailable = false
    @State private var showCSVFilePicker = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - CSV Import
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("从CSV文件导入", systemImage: "doc.text.fill")
                            .font(.headline)

                        Text("导入CSV格式的血压数据文件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        showCSVFilePicker = true
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在导入...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("选择CSV文件导入")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(isImporting)
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                } header: {
                    Text("CSV导入")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• CSV格式: date,time,period,systolic,diastolic,heart_rate")
                        Text("• 示例: 2026-03-19,06:17,AM,126,93,0")
                        Text("• 已存在的记录将被自动跳过")
                    }
                    .font(.caption)
                }

                // MARK: - HealthKit Import
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("从健康App导入", systemImage: "heart.text.square.fill")
                            .font(.headline)

                        Text("导入健康App中的血压数据到本应用")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("⚠️ 需要付费 Apple Developer 账号才能使用此功能")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)

                    Button {
                        showHealthKitUnavailable = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("开始导入")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                } header: {
                    Text("健康App导入")
                }

                // MARK: - Stats
                Section {
                    HStack {
                        Text("总记录数")
                        Spacer()
                        Text("\(store.totalCount())")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("统计信息")
                }
            }
            .navigationTitle("设置")
            .fileImporter(
                isPresented: $showCSVFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleCSVImport(result)
            }
            .alert("导入结果", isPresented: $showImportAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                if let result = importResult {
                    Text("成功导入 \(result.imported) 条记录\n跳过 \(result.skipped) 条重复记录")
                } else if let error = errorMessage {
                    Text(error)
                }
            }
            .alert("功能暂不可用", isPresented: $showHealthKitUnavailable) {
                Button("我知道了", role: .cancel) {}
            } message: {
                Text("HealthKit 导入功能需要付费 Apple Developer 账号（¥688/年）。\n\n您可以通过CSV文件导入血压记录。")
            }
        }
    }

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            isImporting = true

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "无法访问所选文件"
                importResult = nil
                showImportAlert = true
                isImporting = false
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
                isImporting = false
            }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let readings = try CSVImporter.parse(content: content)
                let importedResult = store.importCSVReadings(readings)
                importResult = importedResult
                errorMessage = nil
                showImportAlert = true
            } catch {
                errorMessage = "导入失败: \(error.localizedDescription)"
                importResult = nil
                showImportAlert = true
            }

        case .failure(let error):
            errorMessage = "选择文件失败: \(error.localizedDescription)"
            importResult = nil
            showImportAlert = true
        }
    }
}

#Preview {
    SettingsView()
        .environment(DataStore(modelContext: ModelContext(
            try! ModelContainer(for: BPReading.self)
        )))
}
