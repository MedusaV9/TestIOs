import SwiftUI

/// Stage dressing from the concept art: hanging slogan boards, stencilled
/// crates, a retro TV with a banana on screen, the jackpot jar, lamp heads
/// with light cones, leaf clusters and (optionally) the audience silhouette.
/// Purely decorative — never intercepts touches, adapts to the stage width.
struct StageDecor: View {
    var jackpot: Int? = nil
    var showCrowd = false
    var showCrates = true
    var leftSign = ["Good", "Questions", "Bigger", "Wins!"]
    var rightSign = ["Same", "WiFi.", "Real", "Fun."]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let wide = w >= 1000
            let signW: CGFloat = wide ? 132 : 104
            ZStack {
                Group {
                    LeafCluster(flip: false).frame(width: w * 0.28, height: h * 0.5).position(x: w * 0.06, y: h * 0.78).opacity(0.9)
                    LeafCluster(flip: true).frame(width: w * 0.28, height: h * 0.5).position(x: w * 0.94, y: h * 0.78).opacity(0.9)
                    LeafCluster(flip: true).frame(width: w * 0.2, height: h * 0.32).position(x: w * 0.02, y: h * 0.08).opacity(0.7)
                    LeafCluster(flip: false).frame(width: w * 0.2, height: h * 0.32).position(x: w * 0.98, y: h * 0.08).opacity(0.7)
                }
                Group {
                    SpotlightHead(pointsRight: true).position(x: w * 0.09, y: 26)
                    SpotlightHead(pointsRight: false).position(x: w * 0.91, y: 26)
                    HangingSign(lines: leftSign, tilt: -4).frame(width: signW).position(x: signW * 0.62, y: h * 0.36)
                    HangingSign(lines: rightSign, tilt: 3).frame(width: signW).position(x: w - signW * 0.62, y: h * 0.36)
                }
                if showCrates && wide {
                    SloganCrate(lines: ["QUIZ", "PLAY", "WIN", "TOGETHER"]).frame(width: 118, height: 118).position(x: 84, y: h * 0.76)
                    SloganCrate(lines: ["TEAMWORK", "MAKES", "MONKEY", "MONEY"]).frame(width: 128, height: 118).position(x: w - 84, y: h * 0.78)
                    TVProp().frame(width: 92, height: 82).position(x: 70, y: h * 0.58)
                }
                if let j = jackpot {
                    JackpotJar(amount: j).frame(width: 96, height: 150).position(x: w - (wide ? 190 : 62), y: h * (wide ? 0.72 : 0.6))
                }
                if showCrowd { CrowdSilhouette().frame(height: h * 0.22).position(x: w / 2, y: h - h * 0.09) }
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

/// Dark hanging board with hand-lettered slogan, on two ropes.
struct HangingSign: View {
    var lines: [String]
    var tilt: Double = -4
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 44) {
                Rectangle().fill(Color(hex: "#C8A46A")).frame(width: 3, height: 46)
                Rectangle().fill(Color(hex: "#C8A46A")).frame(width: 3, height: 46)
            }
            VStack(spacing: -1) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(.custom("Poppins-SemiBold", size: i == lines.count - 1 && l.hasSuffix("!") ? 24 : 21))
                        .italic()
                        .foregroundStyle(MM.cream.opacity(0.92))
                }
                Text("👑").font(.system(size: 16)).padding(.top, 4).opacity(0.85)
            }
            .padding(.horizontal, 14).padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(hex: "#3E2A17"), Color(hex: "#2A1A0E")], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: "#6B4A2A"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
            )
        }
        .rotationEffect(.degrees(tilt), anchor: .top)
    }
}

/// Wooden crate with plank seams and a stencilled slogan.
struct SloganCrate: View {
    var lines: [String]
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: "#A97441"), Color(hex: "#7A4E27")], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in Rectangle().fill(Color.black.opacity(0.18)).frame(height: 2); Spacer() }
            }.padding(.vertical, 10)
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color(hex: "#5A3A1C"), lineWidth: 4)
            VStack(spacing: -2) {
                Text("👑").font(.system(size: 11)).opacity(0.8)
                ForEach(lines, id: \.self) { l in Text(l).font(.custom("Poppins-Bold", size: 12)).tracking(1).foregroundStyle(Color(hex: "#3A2410").opacity(0.85)) }
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 10, y: 8)
    }
}

/// Retro TV on a tripod with a banana on screen.
struct TVProp: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#2B2B2B")).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "#4A4A4A"), lineWidth: 3))
                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [Color(hex: "#123D2A"), Color(hex: "#0B2418")], startPoint: .top, endPoint: .bottom)).padding(7)
                Text("🍌").font(.system(size: 26))
                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .center)).padding(7)
            }
            .frame(height: 62)
            HStack(spacing: 4) {
                Text("ON AIR").font(.custom("Poppins-Bold", size: 8)).tracking(1).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 3).fill(MM.red))
            }
            Rectangle().fill(Color(hex: "#3A3A3A")).frame(width: 4, height: 12)
        }
        .shadow(color: .black.opacity(0.5), radius: 10, y: 8)
    }
}

/// Glass jackpot jar with coins and the amount plate.
struct JackpotJar: View {
    var amount: Int
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                // lid
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#3A3A3A")).frame(width: 52, height: 12)
                    Spacer()
                }
                // glass
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.45), lineWidth: 2))
                    .frame(width: 78, height: 96)
                    .padding(.top, 8)
                // coins
                VStack(spacing: -8) {
                    HStack(spacing: -6) { ForEach(0..<3, id: \.self) { _ in Coin(size: 20) } }
                    HStack(spacing: -6) { ForEach(0..<4, id: \.self) { _ in Coin(size: 20) } }
                }.padding(.bottom, 8)
                // label
                Text("JACKPOT").font(.custom("Poppins-Bold", size: 10)).tracking(1.5).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(MM.red))
                    .offset(y: -54)
            }
            .frame(height: 108)
            Text(Money.format(amount))
                .font(.outfit(15, .black)).foregroundStyle(MM.ink)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(MM.gold).shadow(color: MM.goldDark, radius: 0, y: 3))
        }
        .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
    }
}

/// A gold coin with an “M” embossed.
struct Coin: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            Circle().fill(MM.gold).overlay(Circle().strokeBorder(MM.goldDark, lineWidth: 2))
            Text("M").font(.outfit(size * 0.55, .black)).foregroundStyle(MM.goldDark)
        }.frame(width: size, height: size)
    }
}

/// Stage lamp head at the top corner, with a soft glow.
struct SpotlightHead: View {
    var pointsRight: Bool
    var body: some View {
        ZStack {
            Circle().fill(MM.gold.opacity(0.35)).frame(width: 70, height: 70).blur(radius: 18)
            Capsule().fill(LinearGradient(colors: [Color(hex: "#4A4A4A"), Color(hex: "#1E1E1E")], startPoint: .top, endPoint: .bottom)).frame(width: 46, height: 30)
                .overlay(Capsule().fill(MM.gold).frame(width: 30, height: 12).offset(y: 10))
                .rotationEffect(.degrees(pointsRight ? 28 : -28))
        }
    }
}

/// Soft organic leaf cluster (monstera / palm silhouettes) for the wings.
struct LeafCluster: View {
    var flip: Bool
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let base = CGPoint(x: flip ? w * 0.95 : w * 0.05, y: h * 0.98)
            let greens = [Color(hex: "#1F6B3A"), Color(hex: "#17452C"), Color(hex: "#2A8A4A"), Color(hex: "#123D2A")]
            for i in 0..<9 {
                let t = Double(i) / 8
                let ang = (flip ? .pi : 0) + (flip ? 1 : -1) * (0.25 + t * 1.3)
                let len = h * (0.45 + 0.45 * sin(t * .pi))
                let tip = CGPoint(x: base.x + cos(ang) * len, y: base.y + sin(ang) * len)
                let midA = CGPoint(x: base.x + cos(ang - 0.35) * len * 0.55, y: base.y + sin(ang - 0.35) * len * 0.55)
                let midB = CGPoint(x: base.x + cos(ang + 0.35) * len * 0.55, y: base.y + sin(ang + 0.35) * len * 0.55)
                var leaf = Path()
                leaf.move(to: base)
                leaf.addQuadCurve(to: tip, control: midA)
                leaf.addQuadCurve(to: base, control: midB)
                leaf.closeSubpath()
                ctx.fill(leaf, with: .color(greens[i % greens.count].opacity(0.85)))
                // centre vein
                var vein = Path()
                vein.move(to: base)
                vein.addLine(to: tip)
                ctx.stroke(vein, with: .color(Color.black.opacity(0.18)), lineWidth: 1.5)
            }
        }
    }
}

/// Audience silhouettes along the bottom edge (heads, shoulders, raised hands).
struct CrowdSilhouette: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var rng = SeededRandom(seed: 77)
            var p = Path()
            var x: CGFloat = -30
            while x < w + 30 {
                let hw = 26 + CGFloat(rng.next()) * 24
                let hh = h * (0.45 + CGFloat(rng.next()) * 0.4)
                p.addEllipse(in: CGRect(x: x - hw / 2, y: h - hh, width: hw, height: hw))
                p.addRoundedRect(in: CGRect(x: x - hw * 0.9, y: h - hh + hw * 0.7, width: hw * 1.8, height: h), cornerSize: CGSize(width: 12, height: 12))
                if rng.next() > 0.6 {
                    let ax = x + (rng.next() > 0.5 ? 1 : -1) * hw * 0.8
                    p.addRoundedRect(in: CGRect(x: ax - 5, y: h - hh - hw * 0.9, width: 10, height: hw * 1.2), cornerSize: CGSize(width: 5, height: 5))
                    p.addEllipse(in: CGRect(x: ax - 8, y: h - hh - hw * 1.05, width: 16, height: 16))
                }
                x += hw * 1.25 + 6
            }
            ctx.fill(p, with: .color(Color(hex: "#04120C").opacity(0.82)))
        }
        .blur(radius: 1.2)
    }
}

/// Laurel wreath halves for the Siegerehrung title.
struct Laurel: View {
    var flip = false
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = flip ? w * 1.4 : -w * 0.4
            let r = w * 1.35
            for i in 0..<9 {
                let t = Double(i) / 8
                let a = (flip ? .pi : 0) + (flip ? -1 : 1) * (-0.9 + t * 1.4)
                let cpt = CGPoint(x: cx + cos(a) * r, y: h * 0.55 + sin(a) * h * 0.55)
                var leaf = ctx
                leaf.translateBy(x: cpt.x, y: cpt.y)
                leaf.rotate(by: .radians(a + (flip ? -1 : 1) * .pi / 2.4))
                leaf.fill(Path(ellipseIn: CGRect(x: -6, y: -16, width: 12, height: 32)), with: .color(MM.gold))
                leaf.stroke(Path(ellipseIn: CGRect(x: -6, y: -16, width: 12, height: 32)), with: .color(MM.goldDark), lineWidth: 1)
            }
        }
    }
}

/// Banana-yellow swoosh underline for stage headlines.
struct Swoosh: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 0, y: size.height * 0.7))
            p.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.4), control: CGPoint(x: size.width * 0.5, y: size.height * 1.3))
            ctx.stroke(p, with: .color(MM.gold), style: StrokeStyle(lineWidth: size.height * 0.35, lineCap: .round))
            var hi = Path()
            hi.move(to: CGPoint(x: size.width * 0.15, y: size.height * 0.55))
            hi.addQuadCurve(to: CGPoint(x: size.width * 0.7, y: size.height * 0.62), control: CGPoint(x: size.width * 0.45, y: size.height * 0.9))
            ctx.stroke(hi, with: .color(Color(hex: "#FFEA9A").opacity(0.8)), style: StrokeStyle(lineWidth: size.height * 0.08, lineCap: .round))
        }
    }
}
