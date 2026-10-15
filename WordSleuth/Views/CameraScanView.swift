import SwiftUI
import AVFoundation
import Combine

public struct CameraScanView: View {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (UIImage) -> Void
    
    @StateObject private var cameraModel = CameraViewModel()
    @State private var flashOn = false
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraModel.permissionDenied {
                VStack(spacing: 20) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textSecondary)
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Please enable camera access in Settings -> Privacy & Security -> Camera -> WordSleuth to scan puzzles directly.")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        Text("Open Settings")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primary)
                            .cornerRadius(10)
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 10)
                    }
                }
                .padding()
            } else if cameraModel.cameraUnavailable {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill.badge.questionmark")
                        .font(.system(size: 64))
                        .foregroundColor(Theme.textSecondary)
                    Text("Camera Unavailable")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("No back camera detected. If you are running on an iOS Simulator, please use the 'Import Photo' or 'Demo Grid' options on the home screen instead.")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button(action: { dismiss() }) {
                        Text("Go Back")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Theme.primary)
                            .cornerRadius(10)
                    }
                }
                .padding()
            } else if cameraModel.isSessionRunning {
                CameraPreviewView(session: cameraModel.session)
                    .ignoresSafeArea()
            } else {
                VStack {
                    ProgressView()
                        .tint(.white)
                    Text("Starting Camera...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            // Bounding Crop Target Overlay
            VStack {
                Text("Align Wordsearch Puzzle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                    .padding(.top, 40)
                
                Spacer()
                
                // Crop Target Bracket
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.primary, Theme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [40, 20])
                    )
                    .frame(width: 320, height: 320)
                    .overlay(
                        Text("Hold steady to scan grid")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, 12),
                        alignment: .bottom
                    )
                
                Spacer()
                
                // Bottom Controls
                HStack(spacing: 40) {
                    // Flash Toggle
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        flashOn.toggle()
                        cameraModel.toggleFlash(on: flashOn)
                    }) {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    // Shutter Button
                    Button(action: {
                        HapticManager.shared.impact(.heavy)
                        cameraModel.captureImage { image in
                            onCapture(image)
                        }
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 76, height: 76)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 3)
                                    .frame(width: 68, height: 68)
                            )
                    }
                    
                    // Close Button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraModel.checkPermissionsAndStart()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
    }
}

// Camera ViewModel handling AVFoundation lifecycle
class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var permissionDenied = false
    @Published var cameraUnavailable = false
    
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage) -> Void)?
    
    func checkPermissionsAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupSession()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            self.permissionDenied = true
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to access camera device.")
            DispatchQueue.main.async {
                self.cameraUnavailable = true
            }
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        
        // Start camera session in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            self.session.stopRunning()
        }
    }
    
    func captureImage(completion: @escaping (UIImage) -> Void) {
        self.captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
    
    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        // Crop the captured image to match our overlay bracket frame roughly
        let cropped = cropToCenterSquare(image: image)
        captureCompletion?(cropped)
    }
    
    private func cropToCenterSquare(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let size = min(width, height) * 0.8
        
        let x = (width - size) / 2.0
        let y = (height - size) / 2.0
        
        let cropRect = CGRect(x: x, y: y, width: size, height: size)
        
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else { return image }
        
        // Retain original orientation
        return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// UIKit Preview Layer Wrapper
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UICameraPreviewView {
        return UICameraPreviewView(session: session)
    }
    
    func updateUIView(_ uiView: UICameraPreviewView, context: Context) {
        // Handled automatically by layoutSubviews in UICameraPreviewView
    }
}

class UICameraPreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        self.previewLayer = layer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Force the video layer to match bounds dynamically on layout updates
        previewLayer?.frame = self.bounds
    }
}
