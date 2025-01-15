// ./HealthData.swift

import Foundation

struct HealthData: Codable {
    var heartRates: [CodableQuantitySample] = []
    var hrv: [CodableQuantitySample] = []
    var steps: [CodableQuantitySample] = []
    var sleep: [CodableCategorySample] = []
    
    // New properties for additional health data types
    var activeEnergyBurned: [CodableQuantitySample] = []
    var walkingRunningDistance: [CodableQuantitySample] = []
    var flightsClimbed: [CodableQuantitySample] = []
    
    // Aggregated Data
    var activeEnergyBurnedMinute: [CodableQuantitySample] = []
    var activeEnergyBurnedHourly: [CodableQuantitySample] = []
    var activeEnergyBurnedDaily: [CodableQuantitySample] = []
    
    var walkingRunningDistanceMinute: [CodableQuantitySample] = []
    var walkingRunningDistanceHourly: [CodableQuantitySample] = []
    var walkingRunningDistanceDaily: [CodableQuantitySample] = []
    
    var flightsClimbedMinute: [CodableQuantitySample] = []
    var flightsClimbedHourly: [CodableQuantitySample] = []
    var flightsClimbedDaily: [CodableQuantitySample] = []
    
    var stepsMinute: [CodableQuantitySample] = []
    var stepsHourly: [CodableQuantitySample] = []
    var stepsDaily: [CodableQuantitySample] = []
    
}
