// ./CodableQuantitySample.swift

import Foundation
import HealthKit

struct CodableQuantitySample: Codable, Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
    let dataType: String // Indicates the type of health data

    /// Initializes from an HKQuantitySample with an explicit unit.
    init(from sample: HKQuantitySample, unit: HKUnit, dataType: String) {
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.value = sample.quantity.doubleValue(for: unit)
        self.unit = unit.unitString
        self.dataType = dataType
    }

    /// Initializes from HKStatistics for aggregated data with an explicit unit.
    init(from statistics: HKStatistics, unit: HKUnit, dataType: String) {
        self.startDate = statistics.startDate
        self.endDate = statistics.endDate
        if let sum = statistics.sumQuantity() {
            self.value = sum.doubleValue(for: unit)
        } else if let avg = statistics.averageQuantity() {
            self.value = avg.doubleValue(for: unit)
        } else {
            self.value = 0.0
        }
        self.unit = unit.unitString
        self.dataType = dataType
    }
}
