import SwiftUI

struct AddReadingView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var systolicText = ""
    @State private var diastolicText = ""
    @State private var heartRateText = ""
    @State private var measuredAt = Date()
    @State private var showSuccess = false
    @State private var showValidationAlert = false
    @State private var showScanner = false
    @State private var showBPGuide = false
    @FocusState private var focusedField: Field?

    enum Field {
        case systolic, diastolic, heartRate
    }

    private var systolic: Int? { Int(systolicText) }
    private var diastolic: Int? { Int(diastolicText) }
    private var heartRate: Int? { Int(heartRateText) }

    private var currentClassification: BPClassification? {
        guard let sys = systolic, let dia = diastolic,
              (60...260).contains(sys), (40...160).contains(dia) else { return nil }
        return BPClassification.classify(systolic: sys, diastolic: dia)
    }

    private var isValid: Bool {
        guard let sys = systolic, let dia = diastolic, let hr = heartRate else { return false }
        return (60...260).contains(sys) && (40...160).contains(dia) && (30...200).contains(hr)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title + Camera button
                HStack {
                    Text("添加血压记录")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)

                // Real-time indicator
                if let classification = currentClassification {
                    HStack {
                        Circle()
                            .fill(Color(
                                red: classification.color.red,
                                green: classification.color.green,
                                blue: classification.color.blue
                            ))
                            .frame(width: 12, height: 12)
                        Text(classification.rawValue)
                            .font(.headline)
                            .foregroundStyle(Color(
                                red: classification.color.red,
                                green: classification.color.green,
                                blue: classification.color.blue
                            ))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(
                            red: classification.color.red,
                            green: classification.color.green,
                            blue: classification.color.blue
                        ).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Form
                VStack(spacing: 16) {
                    InputField(label: "收缩压 (高压)", placeholder: "eg: 110 mmHg", text: $systolicText)
                        .focused($focusedField, equals: .systolic)
                    InputField(label: "舒张压 (低压)", placeholder: "eg: 80 mmHg", text: $diastolicText)
                        .focused($focusedField, equals: .diastolic)
                    InputField(label: "心率", placeholder: "eg: 70 bpm", text: $heartRateText)
                        .focused($focusedField, equals: .heartRate)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("测量时间")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $measuredAt)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                .padding(.horizontal)

                // Submit button
                Button {
                    focusedField = nil
                    saveReading()
                } label: {
                    Text("保存记录")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isValid ? Color.accentColor : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValid)
                .padding(.horizontal)

                // Reference guide
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("血压参考标准")
                            .font(.headline)
                        Button {
                            showBPGuide = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 4)

                    ForEach(BPClassification.allCases, id: \.self) { level in
                        HStack {
                            Circle()
                                .fill(Color(
                                    red: level.color.red,
                                    green: level.color.green,
                                    blue: level.color.blue
                                ))
                                .frame(width: 10, height: 10)
                            Text(level.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(level.rangeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Color(
                                red: level.color.red,
                                green: level.color.green,
                                blue: level.color.blue
                            ).opacity(0.15)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            measuredAt = Date()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .overlay {
            if showSuccess {
                SuccessToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("输入错误", isPresented: $showValidationAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请确保所有数值在合理范围内")
        }
        .sheet(isPresented: $showScanner) {
            BPScannerView { sys, dia, hr in
                systolicText = "\(sys)"
                diastolicText = "\(dia)"
                heartRateText = "\(hr)"
                measuredAt = Date()
            }
        }
        .sheet(isPresented: $showBPGuide) {
            BPGuideSheet()
        }
    }

    private func saveReading() {
        guard isValid, let sys = systolic, let dia = diastolic, let hr = heartRate else {
            showValidationAlert = true
            return
        }
        store.addReading(systolic: sys, diastolic: dia, heartRate: hr, measuredAt: measuredAt)
        systolicText = ""
        diastolicText = ""
        heartRateText = ""
        measuredAt = Date()

        withAnimation(.spring(duration: 0.3)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSuccess = false }
        }
    }
}

// MARK: - BP Guide Sheet

struct BPGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct GuideRow {
        let classification: BPClassification
        let systolicRange: String
        let diastolicRange: String
        let advice: String
    }

    private let rows: [GuideRow] = [
        GuideRow(classification: .normal,
                 systolicRange: "< 120",
                 diastolicRange: "< 80",
                 advice: "血压处于理想水平，保持健康生活方式即可。建议每年复查一次。"),
        GuideRow(classification: .elevated,
                 systolicRange: "120–129",
                 diastolicRange: "< 80",
                 advice: "血压轻度偏高，尚未达到高血压标准。建议改善饮食、增加运动，每3–6个月复查。"),
        GuideRow(classification: .high1,
                 systolicRange: "130–139",
                 diastolicRange: "80–89",
                 advice: "高血压1期。建议生活方式干预，如有心脑血管高风险，医生可能建议药物治疗。"),
        GuideRow(classification: .high2,
                 systolicRange: "≥ 140",
                 diastolicRange: "≥ 90",
                 advice: "高血压2期。通常需要生活方式干预联合降压药物治疗，定期随访。"),
        GuideRow(classification: .crisis,
                 systolicRange: "≥ 180",
                 diastolicRange: "≥ 120",
                 advice: "高血压危象！需立即就医，可能伴随靶器官损害，属于内科急症。"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Source note
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                        Text("依据 AHA/ACC 2017 血压指南")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Classification cards
                    ForEach(rows, id: \.classification) { row in
                        let c = row.classification
                        let bpColor = Color(red: c.color.red, green: c.color.green, blue: c.color.blue)

                        VStack(alignment: .leading, spacing: 10) {
                            // Header row: color badge + name
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(bpColor)
                                    .frame(width: 6, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(bpColor)
                                    Text(c.rangeDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            // BP range columns
                            HStack(spacing: 0) {
                                BPRangeCell(label: "收缩压 (高压)", value: row.systolicRange, color: bpColor)
                                Divider().frame(height: 36)
                                BPRangeCell(label: "舒张压 (低压)", value: row.diastolicRange, color: bpColor)
                            }
                            .background(bpColor.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(bpColor.opacity(0.2), lineWidth: 1))

                            // Advice
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .padding(.top, 1)
                                Text(row.advice)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: bpColor.opacity(0.12), radius: 4, y: 2)
                        .padding(.horizontal)
                    }

                    // Footer note
                    Text("注：以上标准适用于18岁以上成人，儿童及特殊人群请遵医嘱。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("血压分级详解")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct BPRangeCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.system(size: 18))
                .padding(12)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        }
    }
}

struct SuccessToast: View {
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.appGreen)
                Text("保存成功")
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 4)
            .padding(.top, 20)
            Spacer()
        }
    }
}
