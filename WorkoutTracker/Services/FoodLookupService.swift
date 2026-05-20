// FoodLookupService.swift
// Looks up food items by barcode via the Open Food Facts public API.
//
// Architecture notes:
//   • Singleton — created once, shared via FoodLookupService.shared.
//   • Non-throwing — network / decode errors are mapped to FoodLookupResult.networkError.
//   • The response shape (OFFResponse, OFFProduct, OFFNutriments) is kept private
//     so no other layer depends on the external API's JSON structure.

import Foundation

// MARK: - Open Food Facts Response Shape (private)

private struct OFFResponse: Decodable {
    let status: Int           // 1 = found, 0 = not found
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName:        String?
    let brands:             String?
    let nutriments:         OFFNutriments?
    let servingSize:        String?

    enum CodingKeys: String, CodingKey {
        case productName  = "product_name"
        case brands
        case nutriments
        case servingSize  = "serving_size"
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g:    Double?
    let proteins100g:      Double?
    let carbohydrates100g: Double?
    let fat100g:           Double?

    // OFF uses hyphenated keys for some fields
    enum CodingKeys: String, CodingKey {
        case energyKcal100g    = "energy-kcal_100g"
        case proteins100g      = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g           = "fat_100g"
    }
}

// MARK: - Lookup Result

/// The outcome of a barcode lookup. Distinct cases prevent null-checking at call sites.
enum FoodLookupResult {
    case found(FoodItem)
    case notFound      // Barcode recognised but product unknown in database
    case networkError  // Offline or API unavailable
}

// MARK: - Service

final class FoodLookupService {
    static let shared = FoodLookupService()
    private init() {}

    // MARK: - Constants

    private static let apiBase    = "https://world.openfoodfacts.org/api/v0/product"
    private static let userAgent  = "WorkoutTrackerApp/1.0 (iOS; contact@example.com)"
    private static let timeoutSec = 10.0

    // MARK: - Public

    /// Looks up a food product by barcode via Open Food Facts.
    /// Never throws — all failure modes are captured in `FoodLookupResult`.
    ///
    /// - Parameter barcode: EAN-8, EAN-13, UPC-A, or similar machine-readable code.
    /// - Returns: `.found` with a populated FoodItem, `.notFound`, or `.networkError`.
    func lookup(barcode: String) async -> FoodLookupResult {
        let urlString = "\(Self.apiBase)/\(barcode).json"
        guard let url = URL(string: urlString) else { return .networkError }

        do {
            var request = URLRequest(url: url, timeoutInterval: Self.timeoutSec)
            // OFF requires a descriptive User-Agent for API access
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(OFFResponse.self, from: data)

            guard response.status == 1, let product = response.product else {
                return .notFound
            }

            return .found(buildFoodItem(from: product, barcode: barcode))

        } catch {
            return .networkError
        }
    }

    // MARK: - Private

    /// Converts a raw OFF product into our domain FoodItem.
    private func buildFoodItem(from product: OFFProduct, barcode: String) -> FoodItem {
        // Prefer product name; fall back to brand; fall back to a generic label
        let name = [product.productName, product.brands]
            .compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? "Unknown Product"

        let n = product.nutriments
        return FoodItem(
            name:            name,
            caloriesPer100g: n?.energyKcal100g    ?? 0,
            proteinPer100g:  n?.proteins100g       ?? 0,
            carbsPer100g:    n?.carbohydrates100g  ?? 0,
            fatPer100g:      n?.fat100g            ?? 0,
            servingGrams:    parseServing(product.servingSize) ?? 100,
            barcode:         barcode
        )
    }

    /// Extracts a gram value from raw serving-size strings such as
    /// "30g", "1 serving (30g)", or "100 ml".
    /// Returns nil if no numeric gram value can be found.
    private func parseServing(_ raw: String?) -> Double? {
        guard let raw else { return nil }

        // Prefer explicit gram notation, e.g. "30g" or "1 piece (28.4g)"
        let gramPattern = #"(\d+(?:\.\d+)?)\s*g"#
        if let range = raw.range(of: gramPattern, options: .regularExpression) {
            let match = raw[range].filter { $0.isNumber || $0 == "." }
            return Double(match)
        }

        // Fallback: take the first numeric run in the string
        let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits)
    }
}
