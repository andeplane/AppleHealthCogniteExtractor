// ./HealthKitManager.swift

import HealthKit

class HealthKitManager {
    let healthStore = HKHealthStore()
    
    /// Requests HealthKit authorization for specified data types.
    /// - Returns: A Boolean indicating success or failure.
    func requestHealthKitAccess() async -> Bool {
        // Define the types you want to read
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
              let flightsClimbedType = HKObjectType.quantityType(forIdentifier: .flightsClimbed),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("One or more HealthKit data types are unavailable.")
            return false
        }
        
        let readTypes: Set<HKObjectType> = [
            heartRateType,
            hrvType,
            stepCountType,
            activeEnergyType,
            distanceType,
            flightsClimbedType,
            sleepType
        ]
        
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    print("HealthKit Authorization Error: \(error.localizedDescription)")
                } else {
                    print("HealthKit Authorization Success: \(success)")
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Fetches quantity samples for a given type within a specified date range.
    /// - Parameters:
    ///   - type: The `HKSampleType` to fetch.
    ///   - startDate: The start date for the predicate.
    ///   - endDate: The end date for the predicate.
    /// - Returns: An array of `HKQuantitySample`.
    func fetchQuantitySamples(ofType type: HKSampleType, startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("Error fetching samples for type \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    let quantitySamples = samples as? [HKQuantitySample] ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches category samples for a given type within a specified date range.
    /// - Parameters:
    ///   - type: The `HKSampleType` to fetch.
    ///   - startDate: The start date for the predicate.
    ///   - endDate: The end date for the predicate.
    /// - Returns: An array of `HKCategorySample`.
    func fetchCategorySamples(ofType type: HKSampleType, startDate: Date, endDate: Date) async throws -> [HKCategorySample] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("Error fetching category samples for type \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    let categorySamples = samples as? [HKCategorySample] ?? []
                    continuation.resume(returning: categorySamples)
                }
            }
            healthStore.execute(query)
        }
    }
    
    /// Fetches all heart rate data within a specified date range.
    func fetchHeartRateData(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Heart Rate Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: heartRateType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all heart rate variability data within a specified date range.
    func fetchHRVData(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "HRV Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: hrvType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all step count data within a specified date range.
    func fetchStepCountData(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw NSError(domain: "HealthKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Step Count Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: stepType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all sleep analysis data within a specified date range.
    func fetchSleepAnalysis(startDate: Date, endDate: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NSError(domain: "HealthKitManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Sleep Analysis Type is unavailable."])
        }
        
        return try await fetchCategorySamples(ofType: sleepType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all active energy burned data within a specified date range.
    func fetchActiveEnergyBurned(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw NSError(domain: "HealthKitManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Active Energy Burned Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: activeEnergyType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all walking + running distance data within a specified date range.
    func fetchWalkingRunningDistance(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw NSError(domain: "HealthKitManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Distance Walking/Running Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: distanceType, startDate: startDate, endDate: endDate)
    }
    
    /// Fetches all flights climbed data within a specified date range.
    func fetchFlightsClimbed(startDate: Date, endDate: Date) async throws -> [HKQuantitySample] {
        guard let flightsClimbedType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
            throw NSError(domain: "HealthKitManager", code: 7, userInfo: [NSLocalizedDescriptionKey: "Flights Climbed Type is unavailable."])
        }
        
        return try await fetchQuantitySamples(ofType: flightsClimbedType, startDate: startDate, endDate: endDate)
    }
    
    // MARK: - Aggregation Methods
    
    /// Fetches aggregated active energy burned data.
    func fetchAggregatedActiveEnergyBurned(aggregation: HKStatisticsOptions, startDate: Date, endDate: Date, intervalComponents: DateComponents) async throws -> [HKStatistics] {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw NSError(domain: "HealthKitManager", code: 8, userInfo: [NSLocalizedDescriptionKey: "Active Energy Burned Type is unavailable."])
        }
        
        return try await fetchAggregatedStatistics(for: activeEnergyType, aggregation: aggregation, startDate: startDate, endDate: endDate, intervalComponents: intervalComponents)
    }
    
    /// Fetches aggregated walking + running distance data.
    func fetchAggregatedWalkingRunningDistance(aggregation: HKStatisticsOptions, startDate: Date, endDate: Date, intervalComponents: DateComponents) async throws -> [HKStatistics] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw NSError(domain: "HealthKitManager", code: 9, userInfo: [NSLocalizedDescriptionKey: "Distance Walking/Running Type is unavailable."])
        }
        
        return try await fetchAggregatedStatistics(for: distanceType, aggregation: aggregation, startDate: startDate, endDate: endDate, intervalComponents: intervalComponents)
    }
    
    /// Fetches aggregated flights climbed data.
    func fetchAggregatedFlightsClimbed(aggregation: HKStatisticsOptions, startDate: Date, endDate: Date, intervalComponents: DateComponents) async throws -> [HKStatistics] {
        guard let flightsClimbedType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
            throw NSError(domain: "HealthKitManager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Flights Climbed Type is unavailable."])
        }
        
        return try await fetchAggregatedStatistics(for: flightsClimbedType, aggregation: aggregation, startDate: startDate, endDate: endDate, intervalComponents: intervalComponents)
    }
    
    /// Fetches aggregated steps data.
    func fetchAggregatedSteps(aggregation: HKStatisticsOptions, startDate: Date, endDate: Date, intervalComponents: DateComponents) async throws -> [HKStatistics] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw NSError(domain: "HealthKitManager", code: 11, userInfo: [NSLocalizedDescriptionKey: "Step Count Type is unavailable."])
        }
        
        return try await fetchAggregatedStatistics(for: stepType, aggregation: aggregation, startDate: startDate, endDate: endDate, intervalComponents: intervalComponents)
    }
    
    /// Generic method to fetch aggregated statistics.
    private func fetchAggregatedStatistics(for type: HKQuantityType,
                                           aggregation: HKStatisticsOptions,
                                           startDate: Date,
                                           endDate: Date,
                                           intervalComponents: DateComponents) async throws -> [HKStatistics] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKStatistics], Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: aggregation,
                anchorDate: startDate,
                intervalComponents: intervalComponents
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    print("Error fetching aggregated statistics for type \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let results = results {
                    var stats: [HKStatistics] = []
                    results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                        stats.append(statistics)
                    }
                    continuation.resume(returning: stats)
                } else {
                    continuation.resume(returning: [])
                }
            }
            
            self.healthStore.execute(query)
        }
    }
}
