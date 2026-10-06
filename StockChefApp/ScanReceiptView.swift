import SwiftUI
import PhotosUI

struct ScanReceiptView: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var lines: [ParsedReceiptLine] = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var reachedCreditLimit = false
    @State private var showCamera = false
    @State private var editingLine: ParsedReceiptLine?
    @State private var qualityWarning: String?
    @State private var autoCropped = false
    @State private var cropDraft: ReceiptCropDraft?
    @State private var isPreparingCrop = false

    var body: some View {
        let galleryButtonTitle = lines.isEmpty ? "Choisir dans la galerie" : "Choisir une autre photo"
        NavigationStack {
            Group {
                if isPreparingCrop { ProgressView("Détection locale du ticket…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if isScanning { ProgressView("Lecture locale du ticket…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if lines.isEmpty {
                    EmptyState(title: "Importez votre ticket", icon: "doc.viewfinder", message: "Le texte est lu sur votre iPhone : aucune image n’est envoyée sur Internet.")
                } else {
                    List {
                        if let qualityWarning { Section { Label(qualityWarning, systemImage: "exclamationmark.triangle").foregroundStyle(Color("Terracotta")) } }
                        if autoCropped { Section { Label("Ticket recadré avant lecture", systemImage: "viewfinder") .foregroundStyle(Color("Emerald")) } }
                        Section("Produits détectés") {
                            ForEach(lines) { line in
                                Button { editingLine = line } label: { HStack { VStack(alignment: .leading) { Text(line.name); if let price = line.estimatedPrice { Text("Prix détecté : \(price.formatted(.currency(code: "EUR")))").font(.caption).foregroundStyle(.secondary) } }; Spacer(); Text("\(line.quantity.formatted()) \(line.unit.rawValue)").foregroundStyle(.secondary); Image(systemName: "pencil").foregroundStyle(Color("Emerald")) } }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.primary)
                                    .accessibilityLabel("Modifier \(line.name)")
                            }
                            .onDelete { lines.remove(atOffsets: $0) }
                        }
                    }
                }
            }
            .navigationTitle("Scanner un ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if !lines.isEmpty { Button("Ajouter") { store.add(parsed: lines); dismiss() } }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { showCamera = true } label: {
                        Label("Prendre une photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("receipt-camera-picker")

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(galleryButtonTitle, systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("receipt-gallery-picker")
                    .accessibilityHint("Ouvre votre photothèque pour importer un ticket existant")
                }
                .padding()
            }
            .onChange(of: selectedPhoto) { photo in Task { await prepareCrop(photo) } }
            .sheet(isPresented: $showCamera) {
                CameraPicker(onImage: { image in showCamera = false; Task { await prepareCrop(image) } }, onCancel: { showCamera = false })
                    .ignoresSafeArea()
            }
            .fullScreenCover(item: $cropDraft) { draft in
                ReceiptCropEditor(image: draft.image, initialCrop: draft.suggestedCrop) { crop in
                    cropDraft = nil
                    Task { await scan(draft.image, cropRect: crop) }
                } onCancel: {
                    cropDraft = nil
                }
            }
            .sheet(item: $editingLine) { line in ReceiptLineEditor(line: line) { updated in
                if let index = lines.firstIndex(where: { $0.id == updated.id }) { lines[index] = updated }
            } }
            .alert("Lecture impossible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
            .alert("Vos scans gratuits sont épuisés", isPresented: $reachedCreditLimit) { Button("OK", role: .cancel) {} } message: { Text("Le pack de recharges et Pro Lifetime seront reliés à StoreKit avant la mise en vente.") }
        }
    }

    private func prepareCrop(_ photo: PhotosPickerItem?) async {
        guard let photo else { return }
        defer { selectedPhoto = nil }
        do {
            guard let data = try await photo.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw ScannerError.invalidImage }
            await prepareCrop(image)
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareCrop(_ image: UIImage) async {
        isPreparingCrop = true
        let suggestedCrop = await ReceiptScanner.suggestedCrop(for: image) ?? ReceiptCropDraft.defaultCrop
        isPreparingCrop = false
        cropDraft = ReceiptCropDraft(image: image, suggestedCrop: suggestedCrop)
    }

    private func scan(_ image: UIImage, cropRect: CGRect) async {
        guard store.consumeScanCredit() else { reachedCreditLimit = true; return }
        isScanning = true
        defer { isScanning = false }
        do {
            let result = try await ReceiptScanner.recognize(image, cropRect: cropRect)
            lines = result.lines
            qualityWarning = result.quality.warning
            autoCropped = result.wasAutoCropped
            if lines.isEmpty { errorMessage = "Aucun produit alimentaire connu n’a été détecté. Vous pouvez ajouter vos aliments à la main." }
        }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ReceiptLineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var line: ParsedReceiptLine
    let onSave: (ParsedReceiptLine) -> Void
    init(line: ParsedReceiptLine, onSave: @escaping (ParsedReceiptLine) -> Void) { _line = State(initialValue: line); self.onSave = onSave }
    var body: some View {
        NavigationStack { Form {
            TextField("Produit", text: $line.name)
            Picker("Catégorie", selection: $line.category) { ForEach(FoodCategory.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            TextField("Quantité", value: $line.quantity, format: .number).keyboardType(.decimalPad)
            Picker("Unité", selection: $line.unit) { ForEach(FoodUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            if let price = line.estimatedPrice { Text("Prix détecté : \(price.formatted(.currency(code: "EUR")))").foregroundStyle(.secondary) }
        }.navigationTitle("Corriger le produit").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Valider") { onSave(line); dismiss() }.disabled(line.name.trimmingCharacters(in: .whitespaces).isEmpty || line.quantity <= 0) } } }
    }
}

private struct ReceiptCropDraft: Identifiable {
    let id = UUID()
    let image: UIImage
    let suggestedCrop: CGRect

    static let defaultCrop = CGRect(x: 0.06, y: 0.04, width: 0.88, height: 0.92)
}

/// Preview rendering may be small, but `crop` stays normalized and is applied to the
/// full-resolution CGImage only after confirmation.
private struct ReceiptCropEditor: View {
    let image: UIImage
    let initialCrop: CGRect
    let onConfirm: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var crop: CGRect
    @State private var dragStart: CGRect?

    init(image: UIImage, initialCrop: CGRect, onConfirm: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.initialCrop = initialCrop
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _crop = State(initialValue: initialCrop)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let imageFrame = fittedImageFrame(for: image.size, in: proxy.size)
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)
                    ReceiptCropOverlay(crop: $crop, imageFrame: imageFrame, dragStart: $dragStart)
                }
            }
            .navigationTitle("Recadrer le ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Utiliser ce cadre") { onConfirm(crop) } }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Ajuste les coins au bord du ticket. L’original reste intact.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Réinitialiser") { crop = initialCrop }
                        .font(.footnote.weight(.semibold))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Outil de recadrage du ticket")
    }

    private func fittedImageFrame(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }
}

private struct ReceiptCropOverlay: View {
    @Binding var crop: CGRect
    let imageFrame: CGRect
    @Binding var dragStart: CGRect?

    var body: some View {
        let selection = CGRect(
            x: imageFrame.minX + crop.minX * imageFrame.width,
            y: imageFrame.minY + crop.minY * imageFrame.height,
            width: crop.width * imageFrame.width,
            height: crop.height * imageFrame.height
        )
        ZStack {
            Path { path in
                path.addRect(imageFrame)
                path.addRect(selection)
            }
            .fill(.black.opacity(0.48), style: FillStyle(eoFill: true))

            Rectangle()
                .path(in: selection)
                .stroke(Color("Emerald"), lineWidth: 3)

            ForEach(ReceiptCropHandle.allCases, id: \.self) { handle in
                Circle()
                    .fill(Color("Emerald"))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .position(handle.point(in: selection))
                    .gesture(dragGesture(for: handle))
                    .accessibilityLabel(handle.accessibilityLabel)
                    .accessibilityHint("Faites glisser pour ajuster le cadre")
            }
        }
    }

    private func dragGesture(for handle: ReceiptCropHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStart ?? crop
                dragStart = start
                crop = handle.updatedCrop(from: start, translation: value.translation, imageFrame: imageFrame)
            }
            .onEnded { _ in dragStart = nil }
    }
}

private enum ReceiptCropHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var accessibilityLabel: String {
        switch self {
        case .topLeft: "Coin supérieur gauche"
        case .topRight: "Coin supérieur droit"
        case .bottomLeft: "Coin inférieur gauche"
        case .bottomRight: "Coin inférieur droit"
        }
    }

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func updatedCrop(from start: CGRect, translation: CGSize, imageFrame: CGRect) -> CGRect {
        let minimumSide: CGFloat = 0.12
        let deltaX = translation.width / imageFrame.width
        let deltaY = translation.height / imageFrame.height
        var minX = start.minX
        var maxX = start.maxX
        var minY = start.minY
        var maxY = start.maxY

        switch self {
        case .topLeft:
            minX = min(max(start.minX + deltaX, 0), maxX - minimumSide)
            minY = min(max(start.minY + deltaY, 0), maxY - minimumSide)
        case .topRight:
            maxX = max(min(start.maxX + deltaX, 1), minX + minimumSide)
            minY = min(max(start.minY + deltaY, 0), maxY - minimumSide)
        case .bottomLeft:
            minX = min(max(start.minX + deltaX, 0), maxX - minimumSide)
            maxY = max(min(start.maxY + deltaY, 1), minY + minimumSide)
        case .bottomRight:
            maxX = max(min(start.maxX + deltaX, 1), minX + minimumSide)
            maxY = max(min(start.maxY + deltaY, 1), minY + minimumSide)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
