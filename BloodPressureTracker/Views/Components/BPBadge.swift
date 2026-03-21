import SwiftUI

struct BPBadge: View {
    let classification: BPClassification

    var body: some View {
        Text(classification.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(classification == .crisis ? .white : .primary)
            .background(
                Color(
                    red: classification.color.red,
                    green: classification.color.green,
                    blue: classification.color.blue
                ).opacity(classification == .crisis ? 1.0 : 0.25)
            )
            .clipShape(Capsule())
    }
}

struct ReadingRow: View {
    let reading: BPReading
    let onDelete: () -> Void

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: reading.measuredAt)
    }

    private var ampmString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: reading.measuredAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(timeString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ampmString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(reading.systolic)/\(reading.diastolic) mmHg")
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(reading.heartRate) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            BPBadge(classification: reading.classification)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
