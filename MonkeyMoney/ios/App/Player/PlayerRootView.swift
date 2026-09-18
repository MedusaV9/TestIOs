import SwiftUI
import AVFoundation

/// iPhone root: join (scan QR / code + iPad address), the game controller, the GM cockpit.
struct PlayerRootView: View {
    @EnvironmentObject var player: PlayerModel

    var body: some View {
        ZStack {
            JungleBackground(spotlights: false)
            switch player.screen {
            case .join: JoinView()
            case .playing: PlayView()
            case .gm: PhoneGmView()
            }
            VStack {
                HStack {
                    Spacer()
                    Circle().fill(player.status == .online ? MM.green : (player.status == .connecting ? MM.gold : MM.red)).frame(width: 10, height: 10).shadow(color: player.status == .online ? MM.green : MM.red, radius: 6).padding(12)
                }
                Spacer()
                if let t = player.toast {
                    Text(t).font(.poppins(14, .bold)).foregroundStyle(MM.ink).padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(MM.gold)).padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: player.toast)
        }
        .sheet(isPresented: $player.showScanner) { QRScannerSheet { player.handleScanned($0) } }
        .sheet(item: $player.profileEvent) { e in
            VStack(spacing: 14) {
                Text("🏆").font(.system(size: 60))
                Text("+\(e.atDelta) All-Time").font(.outfit(34, .black)).foregroundStyle(MM.gold)
                if e.levelUp { Text("LEVEL \(e.level)!").font(.outfit(28, .black)).foregroundStyle(MM.cream) }
                ForEach(e.quests, id: \.self) { Text("✔ \($0)").font(.poppins(15, .semibold)).foregroundStyle(MM.cream) }
                Text("Pass-XP: \(e.passXp)").font(.poppins(13)).foregroundStyle(MM.cream.opacity(0.8))
                GoldButton(title: "Nice!", compact: true) { player.profileEvent = nil }
            }.padding(30).presentationDetents([.medium]).presentationBackground(MM.bg)
        }
    }
}

extension ProfileEvent: Identifiable { public var id: String { profileId + String(atGesamt) } }

// MARK: - Join

struct JoinView: View {
    @EnvironmentObject var player: PlayerModel
    @State private var affeIdx = 0
    @State private var step = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack { Text("MONKEY MONEY").font(.outfit(14, .black)).tracking(2).foregroundStyle(MM.gold); Spacer(); if !player.roomCode.isEmpty { Chip(text: "Raum \(player.roomCode)") } }.padding(.top, 8)
                VStack(spacing: -4) {
                    Text("MITSPIELEN").font(.outfit(46, .black)).foregroundStyle(MM.cream).shadow(color: Color(hex: "#A67C1A"), radius: 0, y: 3)
                    Text("CODE · NAME · LOS!").font(.poppins(12, .bold)).tracking(3).foregroundStyle(MM.gold)
                }
                HStack(spacing: 6) {
                    stepDot(1, "Code"); Rectangle().fill(MM.gold.opacity(0.4)).frame(height: 1); stepDot(2, "Affe & Name"); Rectangle().fill(MM.gold.opacity(0.4)).frame(height: 1); stepDot(3, "Los!")
                }.padding(.horizontal, 10)
                PanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        GoldButton(title: "QR-Code auf dem iPad scannen", icon: "qrcode.viewfinder") { player.showScanner = true }
                        Text("oder von Hand:").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.7))
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Raum-Code").font(.poppins(12, .bold)).foregroundStyle(MM.cream)
                                TextField("LZVQ", text: Binding(get: { player.roomCode }, set: { player.roomCode = String($0.uppercased().prefix(4)) })).textFieldStyle(.plain).font(.outfit(30, .black)).foregroundStyle(MM.cream).textInputAutocapitalization(.characters).autocorrectionDisabled().padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("iPad-Adresse").font(.poppins(12, .bold)).foregroundStyle(MM.cream)
                                TextField("192.168.2.224:8080", text: $player.host).textFieldStyle(.plain).font(.poppins(16, .semibold)).foregroundStyle(MM.cream).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                            }
                        }
                        Text("Dein Name").font(.poppins(12, .bold)).foregroundStyle(MM.cream)
                        TextField("Dein Name", text: $player.name).textFieldStyle(.plain).font(.poppins(18, .semibold)).foregroundStyle(MM.cream).padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                        HStack {
                            Button { affeIdx = (affeIdx + 13) % 14; player.avatar.affe = Monkeys.all[affeIdx].id } label: { Image(systemName: "chevron.left").font(.system(size: 22, weight: .black)).frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(MM.panelDark)).foregroundStyle(MM.gold) }
                            Spacer()
                            VStack(spacing: 2) {
                                ZStack(alignment: .bottom) {
                                    Ellipse().fill(Color.black.opacity(0.42)).frame(width: 150, height: 26).blur(radius: 6).offset(y: 8)
                                    MonkeyImage(avatar: player.avatar, face: "jubel").frame(height: 190)
                                        .id(player.avatar.affe + player.avatar.farbe)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                }
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: player.avatar.affe + player.avatar.farbe)
                                Text(Monkeys.monkey(player.avatar.affe).name).font(.outfit(20, .black)).foregroundStyle(MM.cream)
                                Text("„\(Monkeys.monkey(player.avatar.affe).titel)“").font(.poppins(12)).foregroundStyle(MM.cream.opacity(0.75))
                            }
                            Spacer()
                            Button { affeIdx = (affeIdx + 1) % 14; player.avatar.affe = Monkeys.all[affeIdx].id } label: { Image(systemName: "chevron.right").font(.system(size: 22, weight: .black)).frame(width: 50, height: 50).background(RoundedRectangle(cornerRadius: 14).fill(MM.panelDark)).foregroundStyle(MM.gold) }
                        }
                        HStack(spacing: 10) {
                            ForEach(Monkeys.colors, id: \.id) { c in
                                Circle().fill(Color(hex: c.hex)).frame(width: 36, height: 36).overlay(Circle().strokeBorder(.white, lineWidth: player.avatar.farbe == c.id ? 3 : 0)).scaleEffect(player.avatar.farbe == c.id ? 1.15 : 1)
                                    .onTapGesture { player.avatar.farbe = c.id; Haptics.tap() }
                            }
                        }.frame(maxWidth: .infinity)
                        GoldButton(title: "Rein da! 🍌", icon: "play.fill") { player.isGm = false; player.connect() }
                        Group {
                        Button { player.isGm = true; player.gmPin = ""; step = 3 } label: { Text("🎬 Als Show-Master ans Pult (PIN)").font(.poppins(13, .semibold)).foregroundStyle(MM.cream.opacity(0.85)) }.frame(maxWidth: .infinity)
                        if player.isGm {
                            HStack {
                                TextField("PIN", text: $player.gmPin).textFieldStyle(.plain).font(.outfit(26, .black)).keyboardType(.numberPad).foregroundStyle(MM.cream).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3))).frame(width: 130)
                                GoldButton(title: "Ans Pult", style: .green, compact: true) { player.connect() }
                            }
                        }
                        if let e = player.error { Text(e).font(.poppins(13, .bold)).foregroundStyle(MM.red) }
                        }
                    }
                }
                Text("MONKEY MONEY · FRAGEN · FREUNDE · FÜR IMMER").font(.poppins(9, .semibold)).tracking(2).foregroundStyle(MM.cream.opacity(0.5))
            }.padding(16)
        }
        .onAppear { affeIdx = Monkeys.all.firstIndex { $0.id == player.avatar.affe } ?? 0 }
    }

    func stepDot(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text("\(n)").font(.outfit(13, .black)).foregroundStyle(MM.ink).frame(width: 24, height: 24).background(Circle().fill(MM.gold))
            Text(label).font(.poppins(12, .semibold)).foregroundStyle(MM.cream)
        }
    }
}

// MARK: - QR scanner

struct QRScannerSheet: View {
    var onCode: (String) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            QRScannerView(onCode: onCode).ignoresSafeArea()
            VStack {
                HStack { Spacer(); GoldButton(title: "Schließen", style: .ghost, compact: true) { dismiss() }.padding() }
                Spacer()
                Text("QR-Code auf dem iPad in den Rahmen").font(.poppins(15, .bold)).foregroundStyle(.white).padding(10).background(Capsule().fill(Color.black.opacity(0.5))).padding(.bottom, 40)
            }
            RoundedRectangle(cornerRadius: 24).strokeBorder(MM.gold, lineWidth: 4).frame(width: 260, height: 260)
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController { let c = ScannerController(); c.onCode = onCode; return c }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var fired = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !fired, let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let s = obj.stringValue else { return }
        fired = true
        Haptics.success()
        onCode?(s)
    }
}
