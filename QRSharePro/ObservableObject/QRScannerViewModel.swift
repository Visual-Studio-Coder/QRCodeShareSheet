import SwiftUI
import AVFoundation

class QRScannerViewModel: ObservableObject, QRScannerControllerDelegate {
    @ObservedObject var locationManager = LocationManager()
    
    @Published var unshortenedURL: URL?
    @Published var detectedString: String?
    
    @Published var qrCodeImage: UIImage?
    @Published var qrCode: QRCode
    
    @AppStorage("playHaptics") private var playHaptics = PlayHaptics.playHaptics
    
    var qrCodeStore: QRCodeStore
    
    func save() throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    let scannerController = QRScannerController()
    
    init(qrCodeStore: QRCodeStore) {
        self.qrCodeStore = qrCodeStore
        self.qrCode = QRCode(text: "", originalURL: "")
        scannerController.delegate = self
        scannerController.requestCameraPermission()
    }
    
    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.startScanning()
        }
    }
    
    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.scannerController.stopScanning()
        }
    }
    
    @Published var lastDetectedURL: URL?
    @Published var lastDetectedString: String? = ""
    
    let filter = CIFilter.qrCodeGenerator()
    let context = CIContext()
    
    func generateQRCode(from string: String) {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let qrCode = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledQrCode = qrCode.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledQrCode, from: scaledQrCode.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    @MainActor func didDetectQRCode(string: String) {
        if string.isValidURL(), let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
            guard url != URL(string: lastDetectedString!) else { return }
            lastDetectedString = string
            self.detectedString = string
            
            if playHaptics {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            
            let sanitizedURL = url.absoluteString.removeTrackers()
            
            URLSession.shared.dataTask(with: URL(string: sanitizedURL)!.prettify()) { (data, response, error) in
                // prevent maliciously crafted qr codes + actually check we visited the page
                guard error == nil else { return }
                guard let response = response else { return }
                guard let finalURL = response.url else { return }
                
                DispatchQueue.main.async {
                    self.generateQRCode(from: sanitizedURL)
                    
                    let qrCodeImage = self.qrCodeImage!
                    let pngData = qrCodeImage.pngData()!
                    var userLocation: [Double] = [] // re-write user's location in memory
                    
                    if let location = self.locationManager.location {
                        userLocation = [location.latitude, location.longitude]
                    } else {
                        print("Could not get user location.")
                    }
                    
                    let newCode = QRCode(text: finalURL.prettify().absoluteString, originalURL: url.absoluteString, qrCode: pngData, scanLocation: userLocation, wasScanned: true)
                    
                    self.qrCodeStore.history.append(newCode)
                    
                    self.detectedString = finalURL.prettify().absoluteString
                    
                    Task {
                        do {
                            try self.save()
                            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                        } catch {
                            print("Failed to save: \(error.localizedDescription)")
                        }
                    }
                    
                    userLocation = [] // re-write user's location in memory
                    self.unshortenedURL = finalURL.prettify()
                }
            }.resume()
        } else if UIApplication.shared.canOpenURL(URL(string: string)!){
            guard string != lastDetectedString else { return }
            
            if playHaptics {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            
            generateQRCode(from: string)
            
            if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
                var userLocation: [Double] = [] // re-write user's location in memory
                
                if let location = locationManager.location {
                    userLocation = [location.latitude, location.longitude]
                } else {
                    print("Could not get user location.")
                }
                
                let newCode = QRCode(text: string, originalURL: "", qrCode: pngData, scanLocation: userLocation, wasScanned: true)
                
                qrCodeStore.history.append(newCode)
                
                Task {
                    do {
                        try save()
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            lastDetectedString = string
            
            DispatchQueue.main.async {
                self.detectedString = string
            }
        } else {
            guard string != lastDetectedString else { return }
            
            if playHaptics {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
            
            generateQRCode(from: string)
            
            if let qrCodeImage = self.qrCodeImage, let pngData = qrCodeImage.pngData() {
                var userLocation: [Double] = [] // re-write user's location in memory
                
                if let location = locationManager.location {
                    userLocation = [location.latitude, location.longitude]
                } else {
                    print("Could not get user location.")
                }
                
                let newCode = QRCode(text: string, originalURL: "", qrCode: pngData, scanLocation: userLocation, wasScanned: true)
                
                qrCodeStore.history.append(newCode)
                
                Task {
                    do {
                        try save()
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName("com.click.QRShare.dataChanged" as CFString), nil, nil, true)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
            
            lastDetectedString = string
            
            DispatchQueue.main.async {
                self.detectedString = string
            }
        }
    }
}
