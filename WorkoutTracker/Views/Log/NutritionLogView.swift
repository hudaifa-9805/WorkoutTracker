// NutritionLogView.swift
// Daily nutrition tracker: macro ring, meal-type quick-add buttons, and a scrollable
// log of today's meals. Barcode scanning is handled via BarcodeScannerView (full-screen cover).
// AddMealSheet and EditMealSheet are defined at the bottom of this file.

import SwiftUI

// MARK: - Nutrition Log View

struct NutritionLogView: View {
    @EnvironmentObject var nutritionVM: NutritionViewModel
    @State private var showAddMeal: MealType? = nil
    @State private var editingMeal: MealEntry? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                macroRingCard
                mealTypeQuickAdd
                todayMealsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
        .sheet(item: $showAddMeal) { type in
            AddMealSheet(mealType: type)
                .environmentObject(nutritionVM)
        }
        .sheet(item: $editingMeal) { meal in
            EditMealSheet(meal: meal)
                .environmentObject(nutritionVM)
        }
    }

    // MARK: - Macro ring card

    private var macroRingCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                // Calorie ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: nutritionVM.calorieProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)
                        .animation(.spring(response: 0.6), value: nutritionVM.calorieProgress)
                    VStack(spacing: 2) {
                        Text("\(Int(nutritionVM.todayCalories))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ \(Int(nutritionVM.macroTarget.calories))")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.4))
                        Text("kcal")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                // Macro bars
                VStack(spacing: 10) {
                    MacroBar(label: "Protein", value: nutritionVM.todayProtein,
                             target: nutritionVM.macroTarget.protein, color: .blue)
                    MacroBar(label: "Carbs", value: nutritionVM.todayCarbs,
                             target: nutritionVM.macroTarget.carbs, color: .orange)
                    MacroBar(label: "Fat", value: nutritionVM.todayFat,
                             target: nutritionVM.macroTarget.fat, color: .purple)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
    }

    // MARK: - Quick add

    private var mealTypeQuickAdd: some View {
        HStack(spacing: 10) {
            ForEach(MealType.allCases) { type in
                Button(action: { showAddMeal = type }) {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .frame(width: 40, height: 40)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        Text(type.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Today's meals

    private var todayMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)

            if nutritionVM.todayEntries.isEmpty {
                EmptyStateCard(icon: "fork.knife",
                               title: "No meals logged",
                               subtitle: "Tap a meal type above to start tracking")
            } else {
                ForEach(nutritionVM.todayEntries) { meal in
                    MealEntryCard(meal: meal)
                        .onTapGesture { editingMeal = meal }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                nutritionVM.deleteMeal(meal)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
        }
    }
}

// MARK: - Macro Bar

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color

    private var progress: Double { target > 0 ? min(value / target, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 11)).foregroundColor(Color.white.opacity(0.5))
                Spacer()
                Text("\(Int(value))g").font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                Text("/ \(Int(target))g").font(.system(size: 10)).foregroundColor(Color.white.opacity(0.3))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Meal Entry Card

struct MealEntryCard: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)).frame(width: 42, height: 42)
                Image(systemName: meal.type.icon).font(.system(size: 16)).foregroundColor(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.type.rawValue)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(meal.items.isEmpty ? "No items" :
                     meal.items.map(\.name).joined(separator: ", "))
                    .font(.caption).foregroundColor(Color.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.totalCalories)) kcal")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.orange)
                Text("P:\(Int(meal.totalProtein))  C:\(Int(meal.totalCarbs))  F:\(Int(meal.totalFat))")
                    .font(.system(size: 10)).foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white.opacity(0.05)).cornerRadius(14)
    }
}

// MARK: - Add Meal Sheet

struct AddMealSheet: View {
    @EnvironmentObject var nutritionVM: NutritionViewModel
    @Environment(\.dismiss) var dismiss

    let mealType: MealType
    @State private var search          = ""
    @State private var selectedItems: [FoodItem] = []
    @State private var servings: [UUID: Double]  = [:]

    // Barcode scanning
    @State private var showScanner     = false
    @State private var isLookingUp     = false
    @State private var scanBanner: ScanBanner? = nil

    enum ScanBanner: Identifiable {
        case success(String)   // product name
        case notFound
        case error
        var id: Int { switch self { case .success: return 0; case .notFound: return 1; case .error: return 2 } }
    }

    private var filtered: [FoodItem] {
        search.isEmpty ? FoodItem.sampleFoods :
            FoodItem.sampleFoods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Barcode scan row ──────────────────────────────────────
                Section {
                    Button(action: { showScanner = true }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: isLookingUp ? "arrow.triangle.2.circlepath" : "barcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                    .rotationEffect(.degrees(isLookingUp ? 360 : 0))
                                    .animation(isLookingUp ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                                               value: isLookingUp)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isLookingUp ? "Looking up product…" : "Scan Barcode")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("EAN-8 · EAN-13 · UPC · QR")
                                    .font(.caption)
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            Spacer()
                            if isLookingUp {
                                ProgressView().tint(.orange).scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.white.opacity(0.25))
                            }
                        }
                    }
                    .disabled(isLookingUp)
                    .listRowBackground(Color.white.opacity(0.05))

                    // Scan result banner
                    if let banner = scanBanner {
                        scanResultRow(banner)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Barcode")
                }

                // ── Selected items ────────────────────────────────────────
                if !selectedItems.isEmpty {
                    Section("Selected (\(selectedItems.count))") {
                        ForEach(selectedItems) { item in
                            let serving = servings[item.id] ?? item.servingGrams
                            let factor  = serving / 100
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        if item.barcode != nil {
                                            Image(systemName: "barcode")
                                                .font(.system(size: 10))
                                                .foregroundColor(Color.orange.opacity(0.7))
                                        }
                                    }
                                    Text("\(Int(item.caloriesPer100g * factor)) kcal · \(Int(serving))g")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                                Spacer()
                                ServingStepper(value: Binding(
                                    get: { servings[item.id] ?? item.servingGrams },
                                    set: { servings[item.id] = $0 }
                                ))
                            }
                            .listRowBackground(Color.white.opacity(0.07))
                            .swipeActions {
                                Button(role: .destructive) {
                                    selectedItems.removeAll { $0.id == item.id }
                                } label: { Label("Remove", systemImage: "trash") }
                            }
                        }
                    }
                }

                // ── Food library ──────────────────────────────────────────
                Section("Food Library") {
                    ForEach(filtered) { food in
                        Button(action: { addFood(food) }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("\(Int(food.caloriesPer100g)) kcal · P:\(Int(food.proteinPer100g))  C:\(Int(food.carbsPer100g))  F:\(Int(food.fatPer100g)) per 100g")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                                Spacer()
                                if selectedItems.contains(where: { $0.id == food.id }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .searchable(text: $search, prompt: "Search food…")
            .navigationTitle(mealType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { saveMeal() }
                        .fontWeight(.semibold)
                        .foregroundColor(selectedItems.isEmpty ? Color.white.opacity(0.3) : .orange)
                        .disabled(selectedItems.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView { barcode in
                    Task { await handleScan(barcode) }
                }
            }
        }
    }

    // MARK: - Scan result banner

    @ViewBuilder
    private func scanResultRow(_ banner: ScanBanner) -> some View {
        switch banner {
        case .success(let name):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Added \"\(name)\"")
                    .font(.system(size: 13)).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { scanBanner = nil } }) {
                    Image(systemName: "xmark").font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .padding(10)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)

        case .notFound:
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill").foregroundColor(.yellow)
                Text("Product not found in database")
                    .font(.system(size: 13)).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { scanBanner = nil } }) {
                    Image(systemName: "xmark").font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .padding(10)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(10)

        case .error:
            HStack(spacing: 10) {
                Image(systemName: "wifi.slash").foregroundColor(.red)
                Text("Network error — check connection")
                    .font(.system(size: 13)).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { scanBanner = nil } }) {
                    Image(systemName: "xmark").font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(10)
        }
    }

    // MARK: - Actions

    private func addFood(_ food: FoodItem) {
        guard !selectedItems.contains(where: { $0.id == food.id }) else { return }
        selectedItems.append(food)
        servings[food.id] = food.servingGrams
    }

    private func handleScan(_ barcode: String) async {
        withAnimation { isLookingUp = true; scanBanner = nil }
        let result = await FoodLookupService.shared.lookup(barcode: barcode)
        withAnimation { isLookingUp = false }

        switch result {
        case .found(let item):
            addFood(item)
            withAnimation { scanBanner = .success(item.name) }
        case .notFound:
            withAnimation { scanBanner = .notFound }
        case .networkError:
            withAnimation { scanBanner = .error }
        }
    }

    private func saveMeal() {
        var finalItems = selectedItems
        for i in finalItems.indices {
            finalItems[i].servingGrams = servings[finalItems[i].id] ?? finalItems[i].servingGrams
        }
        nutritionVM.addMeal(MealEntry(type: mealType, items: finalItems))
        dismiss()
    }
}

// MARK: - Serving stepper (extracted for reuse)

struct ServingStepper: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 4) {
            Button(action: { value = max(10, value - 10) }) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
            }
            Text("\(Int(value))g")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42)
            Button(action: { value += 10 }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Edit Meal Sheet

struct EditMealSheet: View {
    @EnvironmentObject var nutritionVM: NutritionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var meal: MealEntry

    init(meal: MealEntry) { _meal = State(initialValue: meal) }

    var body: some View {
        NavigationStack {
            List {
                Section("Meal Info") {
                    HStack {
                        Image(systemName: meal.type.icon).foregroundColor(.orange)
                        Text(meal.type.rawValue).foregroundColor(.white)
                        Spacer()
                        Text(meal.date.formatted(date: .omitted, time: .shortened))
                            .foregroundColor(Color.white.opacity(0.4)).font(.caption)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                Section("Items (\(meal.items.count))") {
                    ForEach(meal.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundColor(.white).font(.system(size: 14, weight: .semibold))
                                Text("\(Int(item.calories)) kcal · \(Int(item.servingGrams))g")
                                    .font(.caption).foregroundColor(Color.white.opacity(0.4))
                            }
                            Spacer()
                            Text("P:\(Int(item.protein))  C:\(Int(item.carbs))  F:\(Int(item.fat))")
                                .font(.caption).foregroundColor(Color.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .onDelete { meal.items.remove(atOffsets: $0) }
                }

                Section("Totals") {
                    HStack {
                        MacroChip(label: "kcal", value: Int(meal.totalCalories), color: .orange)
                        MacroChip(label: "P",    value: Int(meal.totalProtein),  color: .blue)
                        MacroChip(label: "C",    value: Int(meal.totalCarbs),    color: .orange)
                        MacroChip(label: "F",    value: Int(meal.totalFat),      color: .purple)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { nutritionVM.updateMeal(meal); dismiss() }
                        .fontWeight(.semibold).foregroundColor(.orange)
                }
            }
        }
    }
}

struct MacroChip: View {
    let label: String; let value: Int; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 10)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1)).cornerRadius(10)
    }
}
