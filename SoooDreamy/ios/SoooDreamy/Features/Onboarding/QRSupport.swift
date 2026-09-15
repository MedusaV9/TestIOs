import SwiftUI
import VisionKit
import CoreImage.CIFilterBuiltins

/// QR payload that carries server + couple code in one scan.
struct PairQRPayload: Codable {
    var v: Int = 1
    var server: String
    var code: String

    static func encode(server: String, code: String) -> String {
        let payload = PairQRPayload(server: server, code: code)
        if let data = try? JSONEncoder().encode(payload),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return code
    }

    static func decode(_ text: String) -> PairQRPayload? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PairQRPayload.self, from: data)
    }
}

enum QRGenerator {
    static func image(for text: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// System QR scanner (VisionKit `DataScannerViewController`): Apple's own
/// camera UI with guidance, item highlighting and pinch-to-zoom instead of a
/// hand-rolled capture session. Shows a `ContentUnavailableView` with a
/// Settings link when camera access is denied.
struct QRScannerView: View {
    @Environment(\.openURL) private var openURL
    let onFound: (String) -> Void

    var body: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScanner(onFound: onFound)
                .ignoresSafeArea()
        } else {
            ContentUnavailableView {
                Label(L10n.t("pairing.scan.unavailable.title"), systemImage: "camera.fill")
            } description: {
                Text(L10n.t("pairing.scan.unavailable.body"))
            } actions: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Button(L10n.t("pairing.scan.openSettings")) { openURL(url) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

/// UIKit bridge for the VisionKit scanner. `DataScannerViewController` is
/// not open, so we do not subclass it — scanning starts on first update
/// and stops when the representable is dismantled or a code is found.
private struct DataScanner: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onFound: (String) -> Void
        private var found = false

        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            deliver(addedItems, from: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            deliver([item], from: dataScanner)
        }

        private func deliver(_ items: [RecognizedItem], from scanner: DataScannerViewController) {
            guard !found else { return }
            for item in items {
                if case .barcode(let barcode) = item, let text = barcode.payloadStringValue {
                    found = true
                    scanner.stopScanning()
                    onFound(text)
                    return
                }
            }
        }
    }
}
