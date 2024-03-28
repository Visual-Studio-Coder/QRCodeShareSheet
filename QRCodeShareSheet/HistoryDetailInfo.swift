//
//  HistoryDetailInfo.swift
//  QRCodeShareSheet
//
//  Created by Aaron Ma on 3/25/24.
//

import SwiftUI
import MapKit

struct ScanLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct HistoryDetailInfo: View {
    @State private var showingAboutAppSheet = false
    @EnvironmentObject var qrCodeStore: QRCodeStore
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showSavedAlert = false
    @State private var showingLocation = false
    @State private var showingFullURLSheet = false
    @State private var qrCodeImage: UIImage = UIImage()
    
    private let monitor = NetworkMonitor()
    
    @State var qrCode: QRCode
    
    func save() async throws {
        qrCodeStore.save(history: qrCodeStore.history)
    }
    
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    
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
    
    func isValidURL(_ string: String) -> Bool {
        if let url = URLComponents(string: string) {
            return url.scheme != nil && !url.scheme!.isEmpty
        } else {
            return false
        }
    }
    
    var body: some View {
        VStack {
            if isEditing {
                NavigationStack {
                    Form {
                        HStack {
                            Spacer()
                            
                            Image(uiImage: qrCodeImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                            
                            Spacer()
                        }
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $qrCode.text)
                                .keyboardType(.webSearch)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: qrCode.text) { newValue in
                                    generateQRCode(from: newValue)
                                }
                            Text(qrCode.text.isEmpty ? "Enter text here…" : "")
                                .foregroundStyle(.gray)
                                .opacity(qrCode.text.isEmpty ? 1 : 0)
                                .padding(.all, 8) // Add padding
                                .font(.system(size: 16)) // Adjust font size
                        }
                        
                        Section {
                            Button {
                                UIImageWriteToSavedPhotosAlbum(qrCodeImage, nil, nil, nil)
                                showSavedAlert = true
                            } label: {
                                Label("Save to Photos", systemImage: "square.and.arrow.down")
                            }
                            .disabled(qrCode.text.isEmpty)
                        }
                    }
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            } else {
                ScrollView {
                    Image(uiImage: qrCodeImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                    
                    VStack(alignment: .leading) {
                        if isValidURL(qrCode.text) {
                            HStack {
                                AsyncCachedImage(url: URL(string: "https://icons.duckduckgo.com/ip3/\(URL(string: qrCode.text)!.host!).ico")) { i in
                                    i
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } placeholder: {
                                    ProgressView()
                                }
                                
                                Text(URL(string: qrCode.text)!.host!)
                                    .font(.largeTitle)
                                    .bold()
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button {
                                    if let url = URL(string: qrCode.text) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Label("Open", systemImage: "safari")
                                        .padding(8)
                                        .foregroundStyle(.white)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                        .bold()
                                }
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading) {
                                Text(qrCode.text)
                                    .lineLimit(2)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .onTapGesture {
                                        showingFullURLSheet = true
                                    }
                            }
                            .padding(.horizontal)
                            .sheet(isPresented: $showingFullURLSheet) {
                                NavigationStack {
                                    List {
                                        Section {
                                            Button {
                                                if let url = URL(string: qrCode.text) {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("Open URL", systemImage: "safari")
                                                    .tint(Color.accentColor)
                                            }
                                        }
                                        
                                        Section("Full URL") {
                                            Button {} label: {
                                                Label("Copy URL", systemImage: "doc.on.doc")
                                                    .tint(Color.accentColor)
                                            }
                                            
                                            Text(qrCode.text)
                                        }
                                    }
                                    .navigationTitle(URL(string: qrCode.text)!.host!)
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("Done") {
                                                showingFullURLSheet = false
                                            }
                                            .tint(Color.accentColor)
                                        }
                                    }
                                }
                            }
                        } else {
                            Text(qrCode.text)
                                .font(.largeTitle)
                                .bold()
                                .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                            .padding(.bottom, 5)
                        
                        if qrCode.wasScanned && !qrCode.scanLocation.isEmpty {
                            Button {
                                withAnimation {
                                    showingLocation.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("SCAN LOCATION")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: showingLocation ? "chevron.down" : "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            if showingLocation {
                                let annotation = [ScanLocation(name: "London", coordinate: CLLocationCoordinate2D(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1]))]
                                
                                Map(coordinateRegion: .constant(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: qrCode.scanLocation[0], longitude: qrCode.scanLocation[1]), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))), interactionModes: [.zoom], annotationItems: annotation) {
                                    MapPin(coordinate: $0.coordinate, tint: .indigo)
                                }
                                .scaledToFit()
                            }
                            
                            Divider()
                                .padding(.horizontal)
                                .padding(.top, 5)
                        }
                        
                        HStack(spacing: 0) {
                            if qrCode.wasScanned {
                                Text("Scanned on: ")
                            } else {
                                Text("Last updated: ")
                            }
                            
                            Text(qrCode.date, format: .dateTime)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            Task {
                generateQRCode(from: qrCode.text)
            }
        }
        .navigationTitle(qrCode.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isValidURL(qrCode.text) {
                    ShareLink(item: URL(string: qrCode.text)!) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    let qrCodeImage = Image(uiImage: qrCodeImage)
                    
                    ShareLink(item: qrCodeImage, preview: SharePreview(qrCode.text, image: qrCodeImage)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                        withAnimation {
                            qrCodeStore.history[idx].pinned.toggle()
                            qrCode.pinned.toggle()
                            
                            Task {
                                do {
                                    try await save()
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    }
                } label: {
                    Label(qrCode.pinned ? "Unpin" : "Pin", systemImage: qrCode.pinned ? "pin.slash.fill" : "pin")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        if isEditing {
                            if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                                qrCode.date = Date.now
                                qrCodeStore.history[idx] = qrCode
                                
                                Task {
                                    do {
                                        try await save()
                                    } catch {
                                        print(error.localizedDescription)
                                    }
                                }
                            }
                        }
                        
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
            }
        }
        .confirmationDialog("Delete QR Code?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete QR Code", role: .destructive) {
                if let idx = qrCodeStore.indexOfQRCode(withID: qrCode.id) {
                    qrCodeStore.history.remove(at: idx)
                    
                    Task {
                        do {
                            try await save()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
                
                showingDeleteConfirmation = false
            }
        }
    }
}

#Preview {
    Group {
        @StateObject var qrCodeStore = QRCodeStore()
        
        NavigationStack {
            HistoryDetailInfo(qrCode: QRCode(text: "https://duckduckgo.com/", scanLocation: [51.507222, -0.1275], wasScanned: true))
                .environmentObject(qrCodeStore)
        }
    }
}
