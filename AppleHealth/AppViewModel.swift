// ./AppViewModel.swift

import SwiftUI
import HealthKit

let perMinuteInterval = DateComponents(minute: 1)
let perHourInterval = DateComponents(hour: 1)
let perDayInterval = DateComponents(day: 1)
let perWeekInterval = DateComponents(weekOfYear: 1)

@MainActor
class AppViewModel: ObservableObject {
    @Published var healthData = HealthData()
    @Published var fetchError: Error?
    @Published var uploadError: Error?
    @Published var progress: Double = 0.0 // Progress from 0.0 to 1.0
    @Published var isFetching: Bool = false
    @Published var isUploading: Bool = false
    @Published var currentDataType: String = ""
    @Published var fetchResults: [String: Int] = [:] // Stores counts for each data type
    @Published var uploadStatus: String = "Ready to upload."
    
    // New properties for upload progress
    @Published var uploadProgress: Double = 0.0 // 0.0 to 1.0
    @Published var uploadCurrentStep: String = "Initializing upload..."
    
    private let healthKitManager = HealthKitManager()
    
    /// Fetches all health data within a specified date range with progress tracking.
    /// - Parameters:
    ///   - startDate: The start date for fetching data.
    ///   - endDate: The end date for fetching data.
    func fetchAllHealthData(startDate: Date, endDate: Date) async {
        // Ensure HealthKit access is granted
        let authorized = await healthKitManager.requestHealthKitAccess()
        guard authorized else {
            return
        }
        
        // Reset previous data and progress
        self.healthData = HealthData()
        self.fetchError = nil
        self.uploadError = nil
        self.progress = 0.0
        self.isFetching = true
        self.isUploading = false
        self.fetchResults = [:]
        self.currentDataType = "Starting data fetch..."
        self.uploadStatus = "Ready to upload."
        
        // Define total number of fetch operations
        let totalFetchOperations = 16
        var completedFetchOperations = 0
        
        // Define the units for each data type
        let units: [String: HKUnit] = [
            "Heart Rates": HKUnit(from: "count/min"),
            "Heart Rate Variability": HKUnit.secondUnit(with: .milli),
            "Steps": HKUnit.count(),
            "Sleep Analysis": HKUnit.count(), // Sleep analysis doesn't use HKUnit, but included for consistency
            "Active Energy Burned": HKUnit.kilocalorie(),
            "Walking + Running Distance": HKUnit.meter(),
            "Flights Climbed": HKUnit.count()
            // Aggregated data types use the same units as their base types
        ]
        
        // Create an array of async tasks with associated data type names
        let fetchTasks: [(String, () async throws -> Int)] = [
            // Heart Rates
            ("Heart Rates", {
                let heartRates = try await self.healthKitManager.fetchHeartRateData(startDate: startDate, endDate: endDate)
                let codableHeartRates = heartRates.map { CodableQuantitySample(from: $0, unit: units["Heart Rates"]!, dataType: "Heart Rates") }
                self.healthData.heartRates = codableHeartRates // Corrected Assignment
                return codableHeartRates.count
            }),
            
            // Heart Rate Variability
            ("Heart Rate Variability", {
                let hrvData = try await self.healthKitManager.fetchHRVData(startDate: startDate, endDate: endDate)
                let codableHRV = hrvData.map { CodableQuantitySample(from: $0, unit: units["Heart Rate Variability"]!, dataType: "Heart Rate Variability") }
                self.healthData.hrv = codableHRV // Corrected Assignment
                return codableHRV.count
            }),
            
            // Steps
            ("Steps", {
                let stepsData = try await self.healthKitManager.fetchStepCountData(startDate: startDate, endDate: endDate)
                let codableSteps = stepsData.map { CodableQuantitySample(from: $0, unit: units["Steps"]!, dataType: "Steps") }
                self.healthData.steps = codableSteps // Corrected Assignment
                return codableSteps.count
            }),
            
            // Sleep Analysis
            ("Sleep Analysis", {
                let sleepData = try await self.healthKitManager.fetchSleepAnalysis(startDate: startDate, endDate: endDate)
                let codableSleep = sleepData.map { CodableCategorySample(from: $0) }
                self.healthData.sleep = codableSleep // Corrected Assignment
                return codableSleep.count
            }),
            
            // Active Energy Burned
            ("Active Energy Burned", {
                let activeEnergy = try await self.healthKitManager.fetchActiveEnergyBurned(startDate: startDate, endDate: endDate)
                let codableActiveEnergy = activeEnergy.map { CodableQuantitySample(from: $0, unit: units["Active Energy Burned"]!, dataType: "Active Energy Burned") }
                self.healthData.activeEnergyBurned = codableActiveEnergy // Corrected Assignment
                return codableActiveEnergy.count
            }),
            
            // Walking + Running Distance
            ("Walking + Running Distance", {
                let distance = try await self.healthKitManager.fetchWalkingRunningDistance(startDate: startDate, endDate: endDate)
                let codableDistance = distance.map { CodableQuantitySample(from: $0, unit: units["Walking + Running Distance"]!, dataType: "Walking + Running Distance") }
                self.healthData.walkingRunningDistance = codableDistance
                return codableDistance.count
            }),
            
            // Flights Climbed
            ("Flights Climbed", {
                let flights = try await self.healthKitManager.fetchFlightsClimbed(startDate: startDate, endDate: endDate)
                let codableFlights = flights.map { CodableQuantitySample(from: $0, unit: units["Flights Climbed"]!, dataType: "Flights Climbed") }
                self.healthData.flightsClimbed = codableFlights
                return codableFlights.count
            }),
            
            // Aggregated Active Energy Burned (Per Minute)
            ("Active Energy Burned - Per Minute", {
                let stats = try await self.healthKitManager.fetchAggregatedActiveEnergyBurned(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perMinuteInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Active Energy Burned"]!, dataType: "Active Energy Burned - Per Minute") }
                self.healthData.activeEnergyBurnedMinute = codableStats
                return codableStats.count
            }),
            
            // Aggregated Active Energy Burned (Hourly)
            ("Active Energy Burned - Hourly", {
                let stats = try await self.healthKitManager.fetchAggregatedActiveEnergyBurned(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perHourInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Active Energy Burned"]!, dataType: "Active Energy Burned - Hourly") }
                self.healthData.activeEnergyBurnedHourly = codableStats
                return codableStats.count
            }),
            
            // Aggregated Active Energy Burned (Daily)
            ("Active Energy Burned - Daily", {
                let stats = try await self.healthKitManager.fetchAggregatedActiveEnergyBurned(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perDayInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Active Energy Burned"]!, dataType: "Active Energy Burned - Daily") }
                self.healthData.activeEnergyBurnedDaily = codableStats
                return codableStats.count
            }),
            
            // Aggregated Walking + Running Distance (Per Minute)
            ("Walking + Running Distance - Per Minute", {
                let stats = try await self.healthKitManager.fetchAggregatedWalkingRunningDistance(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perMinuteInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Walking + Running Distance"]!, dataType: "Walking + Running Distance - Per Minute") }
                self.healthData.walkingRunningDistanceMinute = codableStats
                return codableStats.count
            }),
            
            // Aggregated Walking + Running Distance (Hourly)
            ("Walking + Running Distance - Hourly", {
                let stats = try await self.healthKitManager.fetchAggregatedWalkingRunningDistance(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perHourInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Walking + Running Distance"]!, dataType: "Walking + Running Distance - Hourly") }
                self.healthData.walkingRunningDistanceHourly = codableStats
                return codableStats.count
            }),
            
            // Aggregated Walking + Running Distance (Daily)
            ("Walking + Running Distance - Daily", {
                let stats = try await self.healthKitManager.fetchAggregatedWalkingRunningDistance(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perDayInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Walking + Running Distance"]!, dataType: "Walking + Running Distance - Daily") }
                self.healthData.walkingRunningDistanceDaily = codableStats
                return codableStats.count
            }),
            
            // Aggregated Flights Climbed (Per Minute)
            ("Flights Climbed - Per Minute", {
                let stats = try await self.healthKitManager.fetchAggregatedFlightsClimbed(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perMinuteInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Flights Climbed"]!, dataType: "Flights Climbed - Per Minute") }
                self.healthData.flightsClimbedMinute = codableStats
                return codableStats.count
            }),
            
            // Aggregated Flights Climbed (Hourly)
            ("Flights Climbed - Hourly", {
                let stats = try await self.healthKitManager.fetchAggregatedFlightsClimbed(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perHourInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Flights Climbed"]!, dataType: "Flights Climbed - Hourly") }
                self.healthData.flightsClimbedHourly = codableStats // Corrected Assignment
                return codableStats.count
            }),
            
            // Aggregated Flights Climbed (Daily)
            ("Flights Climbed - Daily", {
                let stats = try await self.healthKitManager.fetchAggregatedFlightsClimbed(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perDayInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Flights Climbed"]!, dataType: "Flights Climbed - Daily") }
                self.healthData.flightsClimbedDaily = codableStats // Corrected Assignment
                return codableStats.count
            }),
            
            // Aggregated Steps (Per Minute)
            ("Steps - Per Minute", {
                let stats = try await self.healthKitManager.fetchAggregatedSteps(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perMinuteInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Steps"]!, dataType: "Steps - Per Minute") }
                self.healthData.stepsMinute = codableStats
                return codableStats.count
            }),
            
            // Aggregated Steps (Hourly)
            ("Steps - Hourly", {
                let stats = try await self.healthKitManager.fetchAggregatedSteps(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perHourInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Steps"]!, dataType: "Steps - Hourly") }
                self.healthData.stepsHourly = codableStats
                return codableStats.count
            }),
            
            // Aggregated Steps (Daily)
            ("Steps - Daily", {
                let stats = try await self.healthKitManager.fetchAggregatedSteps(aggregation: .cumulativeSum, startDate: startDate, endDate: endDate, intervalComponents: perDayInterval)
                let codableStats = stats.map { CodableQuantitySample(from: $0, unit: units["Steps"]!, dataType: "Steps - Daily") }
                self.healthData.stepsDaily = codableStats
                return codableStats.count
            })
        ]
        
        // Iterate through each fetch task using TaskGroup for concurrent execution
        await withTaskGroup(of: (String, Int).self) { group in
            for (dataType, fetchFunction) in fetchTasks {
                group.addTask {
                    // Update current data type before fetching
                    await MainActor.run {
                        self.currentDataType = "Fetching \(dataType)..."
                    }
                    
                    do {
                        let count = try await fetchFunction()
                        return (dataType, count)
                    } catch {
                        // Capture the error and return it via a tuple with count 0
                        await MainActor.run {
                            self.fetchError = error
                        }
                        return (dataType, 0)
                    }
                }
            }
            
            // Process results as tasks complete
            for await (dataType, count) in group {
                // Update fetch results
                self.fetchResults[dataType] = count
                
                // Update progress
                completedFetchOperations += 1
                self.progress = Double(completedFetchOperations) / Double(totalFetchOperations)
                
                // Update status message after each fetch
                await MainActor.run {
                    if let error = self.fetchError, count == 0 {
                        self.currentDataType = "Error fetching \(dataType): \(error.localizedDescription)"
                    } else {
                        self.currentDataType = "Fetched \(count) \(dataType)"
                    }
                }
            }
        }
        
        // Finalize status message
        if self.fetchError == nil {
            self.currentDataType = "All data fetched successfully."
            self.uploadStatus = "Ready to upload to CDF."
        } else {
            self.currentDataType = "Data fetching completed with errors."
            self.uploadStatus = "Upload may be incomplete due to errors."
        }
        
        self.isFetching = false
    }
    
    /// Requests HealthKit authorization.
    /// Uploads health data to CDF.
    func uploadDataToCDF() async {
        guard !fetchResults.isEmpty, fetchError == nil else {
            self.uploadError = NSError(domain: "AppViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data to upload or there were errors during fetching."])
            self.uploadStatus = "Cannot upload due to errors or no data."
            return
        }
        
        self.isUploading = true
        self.uploadStatus = "Uploading data to CDF..."
        self.uploadError = nil
        self.uploadProgress = 0.0
        self.uploadCurrentStep = "Initializing upload..."
        
        // Perform the upload using CogniteAPI with progress tracking
        CogniteAPI.shared.uploadHealthData(healthData: healthData, progressHandler: { [weak self] uploadedBatches, totalBatches in
            guard let self = self else { return }
            let progress = Double(uploadedBatches) / Double(totalBatches)
            self.uploadProgress = progress
            self.uploadCurrentStep = "Uploading... (\(uploadedBatches)/\(totalBatches) batches)"
        }, completion: { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.uploadStatus = "Data uploaded to CDF successfully!"
                self.uploadCurrentStep = "Upload completed."
            } else {
                self.uploadError = error
                self.uploadStatus = "Failed to upload data to CDF: \(error?.localizedDescription ?? "Unknown error")"
                self.uploadCurrentStep = "Upload failed."
            }
            self.isUploading = false
        })
    }
    
    func syncLast24Hours() async {
        // Determine the date range: last 24 hours
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) else {
            print("Failed to calculate start date for last 24 hours sync.")
            return
        }
        
        // Fetch the data
        await fetchAllHealthData(startDate: startDate, endDate: endDate)
        
        // Check for errors
        if let error = fetchError {
            print("Background sync fetch error: \(error.localizedDescription)")
            return
        }
        
        // Upload the data
        await uploadDataToCDF()
        
        // Check for errors
        if let uploadError = uploadError {
            print("Background sync upload error: \(uploadError.localizedDescription)")
            return
        }
        
        print("Background sync completed successfully.")
    }
}
