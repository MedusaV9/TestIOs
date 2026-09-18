import SwiftUI

/// "Fragen-Set": preset tiles with question counts plus an expandable custom
/// category pool (top-level + sub-categories). Used by the mode picker, the
/// lobby settings and the Regiepult — the same control everywhere.
struct QuestionSetPicker: View {
    var sets: [QuestionSetInfo]
    var kategorien: [CategoryInfo]
    var pool: [String]
    var poolInfo: String
    var compact = false
    var onSet: (String) -> Void
    var onPool: ([String]) -> Void
    @State private var showCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📚 Fragen-Set").font(.outfit(compact ? 16 : 18, .bold)).foregroundStyle(MM.gold)
                Spacer()
                Button { withAnimation { showCustom.toggle() } } label: {
                    Label(showCustom ? "Auswahl zu" : "Eigene Auswahl", systemImage: showCustom ? "chevron.up" : "slider.horizontal.3").font(.poppins(12, .semibold))
                }.buttonStyle(.plain).foregroundStyle(MM.cream)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 150 : 170))], spacing: 8) {
                ForEach(sets) { set in
                    Button {
                        if set.id == QuestionSets.eigenId { withAnimation { showCustom = true } } else { Haptics.tap(); onSet(set.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(set.emoji).font(.system(size: compact ? 18 : 22))
                                Text(set.name).font(.outfit(compact ? 14 : 16, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            Text("\(set.anzahl) Fragen").font(.poppins(11, .semibold)).foregroundStyle(set.aktiv ? MM.gold : MM.cream.opacity(0.7))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(MM.cream)
                        .background(RoundedRectangle(cornerRadius: 14).fill(set.aktiv ? MM.gold.opacity(0.18) : Color.black.opacity(0.28))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(set.aktiv ? MM.gold : Color.white.opacity(0.1), lineWidth: set.aktiv ? 2 : 1)))
                    }.buttonStyle(PressStyle())
                }
            }
            if !poolInfo.isEmpty {
                Text(poolInfo).font(.poppins(12, .semibold)).foregroundStyle(MM.gold)
                    .padding(.horizontal, 12).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(MM.gold.opacity(0.1)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MM.gold.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))))
            }
            if showCustom {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        GoldButton(title: "Alle an", style: .ghost, compact: true) { onPool([]) }
                        Text("Kategorie antippen = an/aus · Unterkategorien darunter").font(.poppins(11)).foregroundStyle(MM.cream.opacity(0.7))
                    }
                    ForEach(kategorien) { k in
                        VStack(alignment: .leading, spacing: 4) {
                            Button { Haptics.tap(); onPool(toggled(kat: k.id, sub: nil)) } label: {
                                HStack {
                                    Rectangle().fill(Color(hex: k.farbe)).frame(width: 5, height: 22).clipShape(Capsule())
                                    Text("\(k.emoji) \(k.name)").font(.poppins(13, .bold))
                                    Spacer()
                                    Text("\(k.anzahl)").font(.poppins(11, .semibold)).opacity(0.7)
                                    Image(systemName: k.gewaehlt ? "checkmark.circle.fill" : "circle").foregroundStyle(k.gewaehlt ? MM.gold : MM.cream.opacity(0.4))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7).foregroundStyle(MM.cream)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(k.gewaehlt ? 0.4 : 0.2)))
                            }.buttonStyle(.plain)
                            if !k.unter.isEmpty {
                                FlowChips(items: k.unter.map { ($0.id, "\($0.name) · \($0.anzahl)", $0.gewaehlt) }) { sub in Haptics.tap(); onPool(toggled(kat: k.id, sub: sub)) }
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    /// Toggle a category or one of its sub-categories in the pool (empty pool = everything).
    func toggled(kat: String, sub: String?) -> [String] {
        let allKats = kategorien.map { $0.id }
        var set = Set(pool.isEmpty ? allKats : pool)
        guard let k = kategorien.first(where: { $0.id == kat }) else { return pool }
        if let sub = sub {
            if set.contains(kat) { set.remove(kat); for u in k.unter where u.id != sub { set.insert(u.id) } }
            else if set.contains(sub) { set.remove(sub) }
            else { set.insert(sub); if k.unter.allSatisfy({ set.contains($0.id) }) { for u in k.unter { set.remove(u.id) }; set.insert(kat) } }
        } else {
            if set.contains(kat) { set.remove(kat) } else { set.insert(kat) }
            for u in k.unter { set.remove(u.id) }
        }
        if allKats.allSatisfy({ set.contains($0) }) && set.count == allKats.count { return [] }
        return Array(set).sorted()
    }
}

/// Wrapping row of toggle chips.
struct FlowChips: View {
    var items: [(String, String, Bool)]
    var onTap: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], alignment: .leading, spacing: 5) {
            ForEach(items, id: \.0) { item in
                Button { onTap(item.0) } label: {
                    Text(item.1).font(.poppins(11, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(item.2 ? MM.gold : Color.black.opacity(0.25)))
                        .foregroundStyle(item.2 ? MM.ink : MM.cream.opacity(0.75))
                }.buttonStyle(.plain)
            }
        }
    }
}
