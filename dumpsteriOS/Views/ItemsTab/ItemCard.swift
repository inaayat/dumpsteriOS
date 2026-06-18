import SwiftUI

struct ItemCard: View {
    let item: Item
    var tags: [Tag] = []

    private var displayText: String {
        item.text
            .replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 10) {
            if item.category == .action {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.done ? Theme.successColor : Theme.textMuted.opacity(0.4))
            } else {
                Image(systemName: item.category.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.categoryColor(item.category))
                    .frame(width: 24, height: 24)
                    .background(Theme.categoryTint(item.category), in: Circle())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(displayText)
                    .font(.inter(14))
                    .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(item.done)
                    .lineLimit(2)

                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(3)) { tag in
                            Text("#\(tag.name)")
                                .font(.inter(10))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                if item.priority == .high {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Theme.actionColor, in: Circle())
                }
                if let dueDate = item.dueDate {
                    Text(dueDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.inter(10, weight: .medium))
                        .foregroundStyle(item.isOverdue ? .white : (item.isDueToday ? Theme.warnColor : Theme.textMuted))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.isOverdue ? Color.red : (item.isDueToday ? Theme.warnColor.opacity(0.15) : Theme.cardAlt), in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
