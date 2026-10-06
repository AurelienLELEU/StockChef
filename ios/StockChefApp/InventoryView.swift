import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var showAdd = false
    @State private var storageFilter: StorageLocation?

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    EmptyState(title: "Votre stock est vide", icon: "refrigerator", message: "Scannez un ticket ou ajoutez un aliment.")
                } else {
                    List {
                        ForEach(FoodCategory.allCases, id: \.self) { category in
                            let categoryItems = store.items.filter { $0.category == category && (storageFilter == nil || $0.storageLocation == storageFilter) }
                            if !categoryItems.isEmpty {
                                Section(category.displayName) {
                                    ForEach(categoryItems) { item in
                                        NavigationLink { ItemEditor(item: item) } label: { ItemRow(item: item) }
                                    }
                                    .onDelete { offsets in
                                        offsets.map { categoryItems[$0] }.forEach(store.delete)
                                    }
                                }
                            }
                        }
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Mon stock")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Menu { Button("Tous les emplacements") { storageFilter = nil }; ForEach(StorageLocation.allCases, id: \.self) { location in Button(location.displayName) { storageFilter = location } } } label: { Label(storageFilter?.displayName ?? "Tous", systemImage: storageFilter?.icon ?? "line.3.horizontal.decrease.circle") } }
                ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Label("Ajouter", systemImage: "plus") } }
            }
            .sheet(isPresented: $showAdd) { NavigationStack { ItemEditor() } }
        }
    }
}

struct ItemRow: View {
    let item: InventoryItem
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color("Emerald")).frame(width: 26)
            VStack(alignment: .leading) { Text(item.name); HStack(spacing: 5) { if item.isLeftover { Text("Restes").font(.caption.bold()).foregroundStyle(Color("Terracotta")) }; Text(item.storageLocation.displayName).font(.caption).foregroundStyle(.secondary) }; if let date = item.expiryDate { Text("À consommer : \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(item.expires(within: 3) ? Color("Terracotta") : .secondary) } }
            Spacer(); Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...2)))) \(item.unit.rawValue)").foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private var icon: String { item.category == .vegetable ? "leaf" : item.category == .dairy ? "drop" : "takeoutbag.and.cup.and.straw" }
}

struct ItemEditor: View {
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    private let original: InventoryItem?
    @State private var name = ""
    @State private var category: FoodCategory = .grocery
    @State private var quantity = 1.0
    @State private var unit: FoodUnit = .item
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var storageLocation: StorageLocation = .fridge
    @State private var isLeftover = false

    init(item: InventoryItem? = nil) {
        original = item
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? .grocery)
        _quantity = State(initialValue: item?.quantity ?? 1)
        _unit = State(initialValue: item?.unit ?? .item)
        _hasExpiry = State(initialValue: item?.expiryDate != nil)
        _expiryDate = State(initialValue: item?.expiryDate ?? .now)
        _storageLocation = State(initialValue: item?.storageLocation ?? (item?.category.defaultStorageLocation ?? .fridge))
        _isLeftover = State(initialValue: item?.isLeftover ?? false)
    }

    var body: some View {
        Form {
            TextField("Aliment", text: $name)
            Picker("Catégorie", selection: $category) { ForEach(FoodCategory.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            HStack { TextField("Quantité", value: $quantity, format: .number).keyboardType(.decimalPad); Picker("Unité", selection: $unit) { ForEach(FoodUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden() }
            Toggle("Ajouter une date limite", isOn: $hasExpiry)
            if hasExpiry { DatePicker("À consommer avant", selection: $expiryDate, displayedComponents: .date) }
            Picker("Emplacement", selection: $storageLocation) { ForEach(StorageLocation.allCases, id: \.self) { Label($0.displayName, systemImage: $0.icon).tag($0) } }
            Toggle("Restes maison", isOn: $isLeftover)
            if original != nil { Button("Supprimer", role: .destructive) { if let original { store.delete(original); dismiss() } } }
        }
        .navigationTitle(original == nil ? "Ajouter un aliment" : "Modifier")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || quantity <= 0) } }
    }
    private func save() { let effectiveExpiry = hasExpiry ? expiryDate : (isLeftover && original == nil ? Calendar.current.date(byAdding: .day, value: storageLocation == .freezer ? 90 : 2, to: .now) : nil); let item = InventoryItem(id: original?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces), category: category, quantity: quantity, unit: unit, expiryDate: effectiveExpiry, addedAt: original?.addedAt ?? .now, storageLocation: storageLocation, isLeftover: isLeftover, cookedAt: isLeftover ? (original?.cookedAt ?? .now) : nil); if original == nil { store.add(item) } else { store.update(item) }; dismiss() }
}
