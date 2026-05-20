// BarcodeScannerView.swift
// Full-screen barcode scanner presented as a fullScreenCover from AddMealSheet.
//
// Architecture:
//   BarcodeScannerView (SwiftUI)  — drives six distinct UI states, owns the dismiss / onScan flow.
//   ScannerRepresentable           — thin UIViewControllerRepresentable bridge.
//   ScannerVC (UIViewController)   — owns the AVCaptureSession lifecycle on a dedicated queue.
//
// Bugs fixed in this rewrite (see inline comments):
//   • PRIORITY 1 — setupSession() moved to sessionQueue; stopRunning() off main thread.
//   • PRIORITY 2 — metadataOutput stored as a property; rectOfInterest deferred to after layout.
//   • PRIORITY 3 — sessionQueue used consistently; no streams left open on unmount.
//   • PRIORITY 4 — try/catch on device input; distinct error vs. denied state.

import SwiftUI
import AVFoundation

// MARK: - Scanner State

/// Every lifecycle state the scanner can be in.
/// Equatable is manual because .success and .error carry associated values.
enum BarcodeScannerState: Equatable {
    case requesting        // AVFoundation permission prompt is in-flight
    case scanning          // camera live, decode loop running
    case success(String)   // barcode decoded — associated value is the raw string
    case denied            // user denied camera permission
    case unavailable       // no usable camera device on this hardware
    case error(String)     // unrecoverable error with a human-readable message

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.requesting, .requesting), (.scanning, .scanning),
             (.denied, .denied),         (.unavailable, .unavailable): return true
        case let (.success(a), .success(b)): return a == b
        case let (.error(a),   .error(b)):   return a == b
        default: return false
        }
    }
}

// MARK: - BarcodeScannerView (SwiftUI)

/// Full-screen scanner view. Presents all six states and calls `onScan` with the decoded string.
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var scannerState: BarcodeScannerState = .requesting

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Camera feed — always in the hierarchy so the VC can start its session immediately.
            // Opacity hides it during non-camera states without tearing down the AVCaptureSession.
            ScannerRepresentable(scannerState: $scannerState)
                .ignoresSafeArea()
                .opacity(cameraVisible ? 1 : 0)

            // Per-state UI layer
            stateOverlay
                .animation(.easeInOut(duration: 0.2), value: scannerState)

            // Top navigation bar — always visible so the user can always exit
            topBar
        }
        .ignoresSafeArea()
        // After a successful scan, pause briefly to show the confirmation, then deliver the result.
        .onChange(of: scannerState) { _, newState in
            if case .success(let code) = newState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    onScan(code)
                    dismiss()
                }
            }
        }
    }

    /// Camera feed is visible while scanning and during the brief success confirmation.
    private var cameraVisible: Bool {
        switch scannerState {
        case .scanning, .success: return true
        default: return false
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            Spacer()
            Text("Scan Barcode")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            // Invisible placeholder so the title is visually centred.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - State Overlays

    @ViewBuilder
    private var stateOverlay: some View {
        switch scannerState {
        case .requesting:
            // FIX UI-1: show a spinner while the permission prompt is in-flight.
            spinnerOverlay(label: "Requesting camera access…")
        case .scanning:
            // ScannerVC renders the scan window and animated line; nothing needed from SwiftUI.
            EmptyView()
        case .success(let code):
            // FIX UI-3: show a confirmation card before dismissing.
            successOverlay(code: code)
        case .denied:
            // FIX UI-4 & UI-7: styled consistently with the rest of the app.
            actionableOverlay(
                icon: "camera.slash.fill",
                title: "Camera Access Denied",
                body: "WorkoutTracker needs camera access to scan food barcodes.\n\nEnable it in Settings → Privacy & Security → Camera.",
                actionLabel: "Open Settings",
                action: {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            )
        case .unavailable:
            // FIX UI-8: distinct state for hardware absence.
            infoOverlay(icon: "camera.slash",
                        title: "No Camera Found",
                        body: "This device doesn't appear to have a usable rear camera.")
        case .error(let msg):
            // FIX UI-8: distinct state for non-permission errors.
            actionableOverlay(
                icon: "exclamationmark.triangle.fill",
                title: "Scanner Error",
                body: msg,
                actionLabel: "Dismiss",
                action: { dismiss() }
            )
        }
    }

    /// Centered spinner for transient wait states (requesting, initializing).
    private func spinnerOverlay(label: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    /// Confirmation card shown for ~750 ms after a successful scan.
    private func successOverlay(code: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.green)
                Text("Barcode Detected")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                // Display the raw decoded string so the user can verify what was scanned.
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal, 32)
            Spacer().frame(height: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// Full-screen overlay with icon, explanation, and a single action button.
    private func actionableOverlay(
        icon: String, title: String, body: String,
        actionLabel: String, action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundColor(Color.white.opacity(0.45))
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Button(action: action) {
                Text(actionLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(Color.orange)
                    .cornerRadius(14)
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    /// Informational overlay with no action — used when no remedy is available from in-app.
    private func infoOverlay(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundColor(Color.white.opacity(0.4))
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            Text(body)
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - UIViewControllerRepresentable

private struct ScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannerState: BarcodeScannerState

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        // State changes flow outward via this callback; the binding updates SwiftUI automatically.
        vc.onStateChange = { state in scannerState = state }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {
        // State flows out via onStateChange; nothing to push in.
    }
}

// MARK: - ScannerVC

final class ScannerVC: UIViewController {

    // MARK: Callback

    /// Delivered on the main thread whenever state changes.
    var onStateChange: ((BarcodeScannerState) -> Void)?

    // MARK: Private — AV objects

    private var session:        AVCaptureSession?
    private var previewLayer:   AVCaptureVideoPreviewLayer?
    // FIX BUG-5: store metadataOutput as a property so we can update rectOfInterest after layout.
    private var metadataOutput: AVCaptureMetadataOutput?

    // MARK: Private — overlay views

    private var overlayContainer: UIView?       // full-screen container (tag = overlayTag)
    private var dimLayer:         CAShapeLayer? // fills screen except for the cutout hole
    private var bracketLayer:     CAShapeLayer? // orange corner brackets around the cutout
    private weak var scanLine:    UIView?       // animated horizontal sweep line
    private weak var hintLabel:   UILabel?      // "Point camera at a food barcode" hint

    // MARK: Private — session management

    /// Dedicated serial queue for all AVCaptureSession work.
    /// PRIORITY 1 FIX: AVCaptureSession.startRunning() and stopRunning() are blocking calls
    /// that must NEVER run on the main thread — they stall UIKit rendering.
    private let sessionQueue = DispatchQueue(label: "com.workouttracker.scanner.session",
                                            qos: .userInitiated)

    // MARK: Private — scan deduplication

    /// Set to true once a scan fires; prevents re-entry during the 750 ms success-pause window.
    private var hasFired = false

    // MARK: UIKit tag constant

    // Tag used to locate the full-screen overlay container for layout recalculation.
    private static let overlayTag = 99

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Resume on the session queue. Safe to call even if setup hasn't completed (nil → no-op).
        sessionQueue.async { [weak self] in self?.session?.startRunning() }
    }

    /// PRIORITY 1 FIX: stopRunning() blocks the calling thread — always dispatch off main.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // --- CLEANUP BLOCK — do not remove ---
        // Stops all active capture tracks when the scanner is dismissed.
        // This is the sole cleanup path; there are no open streams after this fires.
        sessionQueue.async { [weak self] in self?.session?.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Resize the preview layer to fill the new bounds (rotation, split-screen, etc.).
        previewLayer?.frame = view.bounds
        // Reposition overlay graphics and recalculate the decode region to match the new layout.
        updateOverlayLayout()
    }

    // MARK: - Permission

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            // Show a spinner while the system permission sheet is in-flight.
            notify(.requesting)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() } else { self?.notify(.denied) }
                }
            }
        case .denied, .restricted:
            notify(.denied)
        @unknown default:
            notify(.error("Unexpected camera authorization state."))
        }
    }

    // MARK: - Session Setup (PRIORITY 1 & 2 fixes)

    /// Configures AVCaptureSession on sessionQueue, then hands UI work back to main.
    /// Must be called only once per VC lifetime.
    private func setupSession() {
        // PRIORITY 1 FIX: heavy AVFoundation work runs on sessionQueue, not main thread.
        sessionQueue.async { [weak self] in
            guard let self else { return }

            let s = AVCaptureSession()
            s.beginConfiguration()
            // FIX BUG-12: set a sensible preset — 4K is wasteful for barcode scanning.
            s.sessionPreset = .hd1280x720

            // Prefer the rear wide-angle camera; fall back to any available video device.
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back)
                            ?? AVCaptureDevice.default(for: .video) else {
                // FIX BUG-9: distinct unavailable state (not a permission error).
                self.notify(.unavailable)
                return
            }

            // PRIORITY 4 FIX: use do/catch instead of try? so errors surface to the UI.
            let videoInput: AVCaptureDeviceInput
            do {
                videoInput = try AVCaptureDeviceInput(device: device)
            } catch {
                // FIX BUG-8: was calling showDenied() for any input error — wrong message.
                self.notify(.error("Could not open camera: \(error.localizedDescription)"))
                return
            }

            guard s.canAddInput(videoInput) else {
                self.notify(.error("Camera input is unavailable on this device."))
                return
            }
            s.addInput(videoInput)

            let output = AVCaptureMetadataOutput()
            guard s.canAddOutput(output) else {
                self.notify(.error("Barcode output is unavailable."))
                return
            }
            s.addOutput(output)
            // Delegate on main queue — results land directly on main, no extra dispatch needed.
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .qr]
            // NOTE: rectOfInterest cannot be set here — view.bounds are not final yet.
            // It is set inside updateOverlayLayout() after the preview layer is in the hierarchy.

            s.commitConfiguration()

            // All UIKit mutations must happen on the main thread.
            // FIX BUG (implicit from original): addOverlay() was never guarded with a main-thread
            // dispatch in the original path where checkPermission → setupSession ran from main,
            // but the async refactor makes the guarantee explicit.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // FIX BUG-5: store both references so updateOverlayLayout can use them.
                self.session        = s
                self.metadataOutput = output

                let layer           = AVCaptureVideoPreviewLayer(session: s)
                layer.frame         = self.view.bounds
                layer.videoGravity  = .resizeAspectFill
                self.view.layer.insertSublayer(layer, at: 0)
                self.previewLayer   = layer

                // Build the overlay graphics; actual positions are set in updateOverlayLayout().
                self.addOverlay()

                // FIX BUG-3 & BUG-4: rectOfInterest is now set here after the preview layer
                // is in the hierarchy and after real layout has run.
                self.updateOverlayLayout()
                self.notify(.scanning)

                // PRIORITY 1 FIX: start the session only after UI is ready.
                // The nested dispatch ensures startRunning queues after this main-thread block.
                self.sessionQueue.async { s.startRunning() }
            }
        }
    }

    // MARK: - Overlay Construction

    /// Builds the overlay container, dim mask, corner brackets, animated scan line, and hint label.
    /// Must be called on the main thread. Positions are set separately by updateOverlayLayout().
    private func addOverlay() {
        // Guard against a second call in case the VC somehow appears twice.
        overlayContainer?.removeFromSuperview()

        // Full-screen container; identified by tag for cleanup/layout.
        let container = UIView(frame: view.bounds)
        container.tag = ScannerVC.overlayTag
        container.isUserInteractionEnabled = false
        view.addSubview(container)
        overlayContainer = container

        // Dimmed background with a transparent cutout using the even-odd fill rule:
        // the inner path (scan window) becomes a "hole" in the solid fill.
        let dim = CAShapeLayer()
        dim.fillRule  = .evenOdd
        dim.fillColor = UIColor.black.withAlphaComponent(0.62).cgColor
        container.layer.addSublayer(dim)
        dimLayer = dim

        // Orange corner-bracket decoration drawn around the cutout edge.
        let brackets = CAShapeLayer()
        brackets.strokeColor = UIColor.systemOrange.cgColor
        brackets.fillColor   = UIColor.clear.cgColor
        brackets.lineWidth   = 3
        brackets.lineCap     = .round
        container.layer.addSublayer(brackets)
        bracketLayer = brackets

        // Horizontal scan line that sweeps top → bottom inside the cutout.
        // Exact frame is set in updateOverlayLayout() once scanRect is known.
        let line = UIView()
        line.backgroundColor    = UIColor.systemOrange.withAlphaComponent(0.85)
        line.layer.cornerRadius = 1
        container.addSubview(line)
        scanLine = line   // weak reference — container retains it strongly

        // Instructional text below the scan window.
        let lbl           = UILabel()
        lbl.text          = "Point camera at a food barcode"
        lbl.textColor     = UIColor.white.withAlphaComponent(0.7)
        lbl.font          = .systemFont(ofSize: 13, weight: .medium)
        lbl.textAlignment = .center
        view.addSubview(lbl)
        hintLabel = lbl   // weak reference — view retains it strongly
    }

    // MARK: - Overlay Layout (PRIORITY 2 fix for rectOfInterest)

    /// Repositions and redraws all overlay graphics to match the current scanRect.
    /// Safe to call repeatedly from viewDidLayoutSubviews.
    private func updateOverlayLayout() {
        guard let overlayContainer, let dimLayer, let bracketLayer,
              let previewLayer else { return }

        // Keep the overlay container filling the screen at all times.
        // FIX BUG-6: the original code moved the dimView to scanRect, which removed all dimming.
        overlayContainer.frame = view.bounds

        let r = scanRect

        // Disable implicit CALayer animations so the path updates are instantaneous.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // --- Dim mask ---
        // Outer path = entire screen. Inner path = rounded scan window.
        // Even-odd rule makes the inner region transparent ("punched out").
        let path = UIBezierPath(rect: view.bounds)
        path.append(UIBezierPath(roundedRect: r, cornerRadius: 14))
        path.usesEvenOddFillRule = true
        dimLayer.path = path.cgPath

        // --- Corner brackets ---
        let bp = UIBezierPath(); let arm: CGFloat = 22
        // Top-left
        bp.move(to: .init(x: r.minX,       y: r.minY + arm))
        bp.addLine(to: .init(x: r.minX,     y: r.minY))
        bp.addLine(to: .init(x: r.minX + arm, y: r.minY))
        // Top-right
        bp.move(to: .init(x: r.maxX - arm,  y: r.minY))
        bp.addLine(to: .init(x: r.maxX,     y: r.minY))
        bp.addLine(to: .init(x: r.maxX,     y: r.minY + arm))
        // Bottom-right
        bp.move(to: .init(x: r.maxX,        y: r.maxY - arm))
        bp.addLine(to: .init(x: r.maxX,     y: r.maxY))
        bp.addLine(to: .init(x: r.maxX - arm, y: r.maxY))
        // Bottom-left
        bp.move(to: .init(x: r.minX + arm,  y: r.maxY))
        bp.addLine(to: .init(x: r.minX,     y: r.maxY))
        bp.addLine(to: .init(x: r.minX,     y: r.maxY - arm))
        bracketLayer.path = bp.cgPath

        CATransaction.commit()

        // --- Scan line ---
        // Cancel any in-flight animation before repositioning to avoid frame conflicts.
        if let line = scanLine {
            line.layer.removeAllAnimations()
            line.frame = CGRect(x: r.minX + 4, y: r.minY, width: r.width - 8, height: 2)
            // FIX BUG-13: animation now uses the correct, post-layout scanRect coordinates.
            UIView.animate(withDuration: 1.6, delay: 0.1,
                           options: [.repeat, .autoreverse, .curveEaseInOut]) {
                line.frame.origin.y = r.maxY - 2
            }
        }

        // --- Hint label ---
        // FIX BUG-14: position derived from the real scanRect, not the pre-layout value.
        if let lbl = hintLabel {
            lbl.sizeToFit()
            lbl.center = CGPoint(x: view.bounds.midX,
                                 y: r.maxY + 28 + lbl.bounds.height / 2)
        }

        // --- rectOfInterest ---
        // PRIORITY 2 FIX: this is the core decode-region bug.
        // metadataOutputRectConverted maps layer-space CGRect → normalized AVFoundation
        // coordinates (origin top-left, values 0…1). Setting this restricts AVFoundation
        // to only decode barcodes that appear inside the visible scan window.
        //
        // FIX BUG-3: was set during setupSession() using view.bounds == CGRect.zero,
        // producing a garbage rect that ignored all barcodes on the actual screen.
        // FIX BUG-4: was never recalculated after layout; now runs every layout pass.
        if let output = metadataOutput {
            output.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: r)
        }
    }

    // MARK: - Scan Rect

    /// Centered square scan window. Max 280 pt, always 32 pt clear of screen edges.
    private var scanRect: CGRect {
        let side = min(view.bounds.width - 64, 280.0)
        return CGRect(
            x: (view.bounds.width  - side) / 2,
            y: (view.bounds.height - side) / 2 - 40,
            width: side, height: side
        )
    }

    // MARK: - State Notification

    /// Thread-safe state delivery — always lands on the main thread.
    private func notify(_ state: BarcodeScannerState) {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerVC: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        // PRIORITY 2 FIX: hasFired prevents duplicate events during the 750 ms success-pause.
        guard !hasFired,
              let obj  = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue,
              !code.isEmpty else { return }

        hasFired = true

        // PRIORITY 3 / FIX BUG-10: stopRunning() on the session queue — never on main.
        sessionQueue.async { [weak self] in self?.session?.stopRunning() }

        // Haptic feedback fires here (in the VC) so it's always tied to the decode event,
        // regardless of how the caller implements onScan. Delegate already fires on main.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        notify(.success(code))
    }
}
