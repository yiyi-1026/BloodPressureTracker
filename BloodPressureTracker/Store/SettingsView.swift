import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @State private var healthKitManager = HealthKitManager()
    @State private var isImporting = false
    @State private var showImportAlert = false
    @State private var importResult: (imported: Int, skipped: Int)?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("从健康App导入", systemImage: "heart.text.square.fill")
                            .font(.headline)
                        
                        Text("导入健康App中的血压数据到本应用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if !healthKitManager.isHealthKitAvailable {
                            Text("此设备不支持健康数据")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        Task {
                            await importFromHealthKit()
                        }
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("正在导入...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("开始导入")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(isImporting || !healthKitManager.isHealthKitAvailable)
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                } header: {
                    Text("数据导入")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 自动从健康App导入血压记录")
                        Text("• 如果没有心率数据，将默认设置为 60 bpm")
                        Text("• 已存在的记录将被跳过")
                    }
                    .font(.caption)
                }
                
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
            .alert("导入完成", isPresented: $showImportAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                if let result = importResult {
                    Text("成功导入 \(result.imported) 条记录\n跳过 \(result.skipped) 条重复记录")
                } else if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func importFromHealthKit() async {
        isImporting = true
        defer { isImporting = false }
        
        // 请求授权
        let authorized = await healthKitManager.requestAuthorization()
        guard authorized else {
            errorMessage = healthKitManager.authorizationError ?? "授权失败"
            importResult = nil
            showImportAlert = true
            return
        }
        
        // 导入数据
        do {
            let readings = try await healthKitManager.importBloodPressureData()
            
            // 保存到数据库
            let result = store.importReadings(readings)
            importResult = result
            errorMessage = nil
            showImportAlert = true
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
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
