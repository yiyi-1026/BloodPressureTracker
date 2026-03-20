import SwiftUI
import Vision
import AVFoundation

struct BPScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var onRecognized: (Int, Int, Int) -> Void  // systolic, diastolic, heartRate

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var recognizedNumbers: [Int] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    @State private var systolicText = ""
    @State private var diastolicText = ""
    @State private var heartRateText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview or placeholder
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("拍摄血压计屏幕")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("请确保数字清晰可见")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            showCamera = true
                        } label: {
                            Label("拍照", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("相册", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)

                    if isProcessing {
                        ProgressView("识别中...")
                            .padding()
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Recognized results (editable)
                    if capturedImage != nil && !isProcessing {
                        VStack(spacing: 16) {
                            Text("识别结果")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !recognizedNumbers.isEmpty {
                                Text("识别到的数字: \(recognizedNumbers.map(String.init).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            InputField(label: "收缩压 (高压)", placeholder: "SYS mmHg", text: $systolicText)
                            InputField(label: "舒张压 (低压)", placeholder: "DIA mmHg", text: $diastolicText)
                            InputField(label: "心率", placeholder: "PUL bpm", text: $heartRateText)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        .padding(.horizontal)

                        Button {
                            confirmReading()
                        } label: {
                            Text("确认并保存")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isResultValid ? Color.accentColor : Color.gray.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isResultValid)
                        .padding(.horizontal)
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("拍照提示")
                            .font(.headline)
                        Text("• 将血压计屏幕正对镜头")
                        Text("• 保持画面稳定，避免反光")
                        Text("• 确保数字完整显示在画面内")
                        Text("• 识别后请核对数值是否正确")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            .navigationTitle("扫描血压计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    handleCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    handleCapturedImage(image)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var isResultValid: Bool {
        guard let sys = Int(systolicText), let dia = Int(diastolicText), let hr = Int(heartRateText) else {
            return false
        }
        return (60...260).contains(sys) && (40...160).contains(dia) && (30...200).contains(hr)
    }

    private func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        errorMessage = nil
        recognizedNumbers = []
        systolicText = ""
        diastolicText = ""
        heartRateText = ""
        isProcessing = true
        let processedImage = preprocessForOCR(image)
        recognizeText(from: processedImage)
    }

    // Preprocess image to improve OCR accuracy on LCD segmented displays
    private func preprocessForOCR(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let enhanced = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,   // grayscale
            kCIInputContrastKey: 1.8,
            kCIInputBrightnessKey: 0.05
        ])
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(enhanced, from: enhanced.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }

    private func confirmReading() {
        guard let sys = Int(systolicText),
              let dia = Int(diastolicText),
              let hr = Int(heartRateText) else { return }
        onRecognized(sys, dia, hr)
        dismiss()
    }

    // MARK: - Vision OCR

    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            errorMessage = "无法处理图片"
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                isProcessing = false

                if let error = error {
                    errorMessage = "识别失败: \(error.localizedDescription)"
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    errorMessage = "未识别到文字"
                    return
                }

                let positioned = self.extractNumbersWithPositions(from: observations)
                recognizedNumbers = positioned.map { $0.value }
                self.assignBPValuesFromPositions(positioned)

                if positioned.isEmpty {
                    errorMessage = "未识别到数字，请重新拍摄"
                }
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "zh-Hans"]
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.02  // detect smaller numbers too

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private struct NumberPosition {
        let value: Int
        let midY: CGFloat   // Vision normalized Y: 1.0 = top, 0.0 = bottom
        let height: CGFloat // bounding box height, larger = more prominent
    }

    // Extract 2-3 digit numbers together with their vertical positions in the image
    private func extractNumbersWithPositions(from observations: [VNRecognizedTextObservation]) -> [NumberPosition] {
        var results: [NumberPosition] = []
        let pattern = #"\d{2,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return results }

        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            let midY = observation.boundingBox.midY
            let height = observation.boundingBox.height

            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                if let matchRange = Range(match.range, in: text),
                   let num = Int(text[matchRange]),
                   (30...260).contains(num) {
                    results.append(NumberPosition(value: num, midY: midY, height: height))
                }
            }
        }
        return results
    }

    // Assign BP values using vertical position:
    // Blood pressure monitors display SYS at top, DIA in middle, heart rate at bottom.
    // Vision framework Y coordinates: 1.0 = top of image, 0.0 = bottom.
    private func assignBPValuesFromPositions(_ positions: [NumberPosition]) {
        guard !positions.isEmpty else { return }

        // Sort top-to-bottom (descending Y)
        let sorted = positions.sorted { $0.midY > $1.midY }

        let sysRange = 60...260
        let diaRange = 40...160
        let hrRange  = 30...200

        // Systolic: topmost number in a valid systolic range
        guard let sys = sorted.first(where: { sysRange.contains($0.value) }) else {
            // Fallback: assign by position order
            if sorted.count >= 1 { systolicText  = "\(sorted[0].value)" }
            if sorted.count >= 2 { diastolicText  = "\(sorted[1].value)" }
            if sorted.count >= 3 { heartRateText  = "\(sorted[2].value)" }
            return
        }
        systolicText = "\(sys.value)"

        // Diastolic: first number below systolic that is less than systolic value
        let belowSys = sorted.filter { $0.midY < sys.midY }
        guard let dia = belowSys.first(where: { diaRange.contains($0.value) && $0.value < sys.value }) else {
            if belowSys.count >= 1 { diastolicText = "\(belowSys[0].value)" }
            if belowSys.count >= 2 { heartRateText  = "\(belowSys[1].value)" }
            return
        }
        diastolicText = "\(dia.value)"

        // Heart rate: first number below diastolic, not equal to sys or dia
        let belowDia = sorted.filter { $0.midY < dia.midY }
        if let hr = belowDia.first(where: { hrRange.contains($0.value) && $0.value != sys.value && $0.value != dia.value }) {
            heartRateText = "\(hr.value)"
        } else if let hr = sorted.first(where: { hrRange.contains($0.value) && $0.value != sys.value && $0.value != dia.value }) {
            heartRateText = "\(hr.value)"
        }
    }
}

// MARK: - UIImagePickerController Wrapper

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
