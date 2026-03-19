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
                // Title
                Text("添加血压记录")
                    .font(.system(size: 28, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    InputField(label: "收缩压 (高压)", placeholder: "60-260 mmHg", text: $systolicText)
                    InputField(label: "舒张压 (低压)", placeholder: "40-160 mmHg", text: $diastolicText)
                    InputField(label: "心率", placeholder: "30-200 bpm", text: $heartRateText)

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
                    Text("血压参考标准")
                        .font(.headline)
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
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SuccessToast: View {
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
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
