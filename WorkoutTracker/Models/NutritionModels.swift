// NutritionModels.swift
// Core data types for the nutrition-tracking feature:
//   FoodItem — a single food with per-100 g macros and a serving size
//   MealType — breakfast / lunch / dinner / snack
//   MealEntry — a timestamped meal containing one or more food items
//   MacroTarget — the user's daily calorie / macro goals

import Foundation

// MARK: - Food Item

/// A food from the library (or scanned via barcode). Stores per-100 g macros;
/// computed properties scale values to the chosen serving size.
struct FoodItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    /// Actual serving size in grams — used to scale computed macro values.
    var servingGrams: Double
    /// Optional barcode that was used to look this item up.
    var barcode: String?

    init(
        id: UUID = UUID(),
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        servingGrams: Double = 100,
        barcode: String? = nil
    ) {
        self.id              = id
        self.name            = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g  = proteinPer100g
        self.carbsPer100g    = carbsPer100g
        self.fatPer100g      = fatPer100g
        self.servingGrams    = servingGrams
        self.barcode         = barcode
    }

    // MARK: Computed Serving Values

    var calories: Double { caloriesPer100g * servingGrams / 100 }
    var protein: Double  { proteinPer100g  * servingGrams / 100 }
    var carbs: Double    { carbsPer100g    * servingGrams / 100 }
    var fat: Double      { fatPer100g      * servingGrams / 100 }
}

// MARK: - Meal Type

/// The part of the day a meal belongs to. Drives icon and accent color in the UI.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"

    var id: String { rawValue }

    /// SF Symbol representing this meal type.
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.fill"
        case .snack:     return "leaf.fill"
        }
    }

    /// Color name (mapped to SwiftUI Color by name in views).
    var color: String {
        switch self {
        case .breakfast: return "yellow"
        case .lunch:     return "orange"
        case .dinner:    return "blue"
        case .snack:     return "green"
        }
    }
}

// MARK: - Meal Entry

/// A single logged meal — a timestamped collection of food items.
struct MealEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var type: MealType
    var items: [FoodItem]
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        type: MealType,
        items: [FoodItem] = [],
        notes: String = ""
    ) {
        self.id    = id
        self.date  = date
        self.type  = type
        self.items = items
        self.notes = notes
    }

    // MARK: Computed Totals

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double  { items.reduce(0) { $0 + $1.protein }  }
    var totalCarbs: Double    { items.reduce(0) { $0 + $1.carbs }    }
    var totalFat: Double      { items.reduce(0) { $0 + $1.fat }      }
}

// MARK: - Macro Target

/// The user's daily nutrition goals. Persisted separately from meal entries so
/// a target change doesn't require re-saving the entire history.
struct MacroTarget: Codable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    /// Sensible defaults for a moderately active person aiming to build muscle.
    static let `default` = MacroTarget(calories: 2000, protein: 150, carbs: 220, fat: 65)
}

// MARK: - Sample Foods

extension FoodItem {
    /// Common whole foods used as the default food library.
    static let sampleFoods: [FoodItem] = [
        FoodItem(name: "Chicken Breast",      caloriesPer100g: 165, proteinPer100g: 31,   carbsPer100g: 0,   fatPer100g: 3.6),
        FoodItem(name: "White Rice (cooked)", caloriesPer100g: 130, proteinPer100g: 2.7,  carbsPer100g: 28,  fatPer100g: 0.3),
        FoodItem(name: "Whole Egg",           caloriesPer100g: 155, proteinPer100g: 13,   carbsPer100g: 1,   fatPer100g: 11),
        FoodItem(name: "Oats (dry)",          caloriesPer100g: 389, proteinPer100g: 17,   carbsPer100g: 66,  fatPer100g: 7),
        FoodItem(name: "Salmon",              caloriesPer100g: 208, proteinPer100g: 20,   carbsPer100g: 0,   fatPer100g: 13),
        FoodItem(name: "Greek Yogurt",        caloriesPer100g: 59,  proteinPer100g: 10,   carbsPer100g: 3.6, fatPer100g: 0.4),
        FoodItem(name: "Banana",              caloriesPer100g: 89,  proteinPer100g: 1.1,  carbsPer100g: 23,  fatPer100g: 0.3),
        FoodItem(name: "Broccoli",            caloriesPer100g: 34,  proteinPer100g: 2.8,  carbsPer100g: 7,   fatPer100g: 0.4),
        FoodItem(name: "Almonds",             caloriesPer100g: 579, proteinPer100g: 21,   carbsPer100g: 22,  fatPer100g: 50),
        FoodItem(name: "Whey Protein Shake",  caloriesPer100g: 370, proteinPer100g: 80,   carbsPer100g: 5,   fatPer100g: 3),
        FoodItem(name: "Sweet Potato",        caloriesPer100g: 86,  proteinPer100g: 1.6,  carbsPer100g: 20,  fatPer100g: 0.1),
        FoodItem(name: "Cottage Cheese",      caloriesPer100g: 98,  proteinPer100g: 11,   carbsPer100g: 3.4, fatPer100g: 4.3),
        FoodItem(name: "Tuna (canned)",       caloriesPer100g: 116, proteinPer100g: 26,   carbsPer100g: 0,   fatPer100g: 1),
        FoodItem(name: "Olive Oil",           caloriesPer100g: 884, proteinPer100g: 0,    carbsPer100g: 0,   fatPer100g: 100),
        FoodItem(name: "Mixed Nuts",          caloriesPer100g: 607, proteinPer100g: 20,   carbsPer100g: 21,  fatPer100g: 54),
    ]
}
