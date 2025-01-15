import Foundation
import HealthKit

struct CodableCategorySample: Codable, Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let value: Int
    let categoryType: String
    
    /// Initializes from an HKCategorySample.
    init(from sample: HKCategorySample) {
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.value = sample.value
        self.categoryType = sample.categoryType.identifier
    }
}
