// ./CogniteAPI.swift

import Foundation

// MARK: - Configuration Structure
struct CogniteConfig {
    static var clusterName: String {
        return UserDefaults.standard.string(forKey: "cdf_clusterName") ?? "api"
    }
    
    static var project: String {
        return UserDefaults.standard.string(forKey: "cdf_project") ?? "andershaf"
    }
    
    static var tenantID: String {
        return UserDefaults.standard.string(forKey: "cdf_tenantID") ?? "5409fe5e-39ad-4448-90ad-6688455011bf"
    }
    
    static var clientID: String {
        return UserDefaults.standard.string(forKey: "cdf_clientID") ?? "d2d8009c-6c86-4dee-8633-588ec4f07027"
    }
    
    static var clientSecret: String? {
        guard let data = KeychainHelper.standard.read(service: "com.cognite.CDF", account: "clientSecret"),
              let secret = String(data: data, encoding: .utf8) else {
            return nil
        }
        return secret
    }
    
    static var space: String {
        return UserDefaults.standard.string(forKey: "cdf_space") ?? "hoff_terrasse_3"
    }
    
    static var baseURL: String {
        return "https://\(clusterName).cognitedata.com"
    }
    
    static var tokenURL: String {
        return "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token"
    }
    
    static var tokenScopes: String {
        return "https://\(clusterName).cognitedata.com/.default"
    }
}

// Represents a single data point in a time series
struct CDFDataPoint: Codable {
    let timestamp: Int64 // Unix timestamp in milliseconds
    let value: Double
}

// Represents a time series with an external ID and associated data points
struct CDFTimeSeries: Codable {
    let externalId: String
    let datapoints: [CDFDataPoint]
}

// MARK: - Time Series Definition Structure
struct TimeSeriesDefinition {
    let externalId: String
    let name: String
    let type: String // e.g., "numeric"
    let description: String
    let unit: String
}

// MARK: - Token Response Structure
struct TokenResponse: Codable {
    let token_type: String
    let expires_in: Int
    let access_token: String
}

// MARK: - CogniteAPI Class
class CogniteAPI {
    static let shared = CogniteAPI()
    
    private init() {}
    
    private var accessToken: String?
    private var tokenExpiryDate: Date?
    
    // MARK: - Authentication Method
    /// Authenticates with Cognite using client credentials to obtain an access token.
    /// - Parameter completion: Completion handler with a success flag and optional error.
    func authenticate(completion: @escaping (Bool, Error?) -> Void) {
        print("Starting authentication process...")
        
        // Check if accessToken exists and is still valid
        let safetyMargin: TimeInterval = 300 // 5 minutes
        if let expiry = tokenExpiryDate, let _ = accessToken, Date().addingTimeInterval(safetyMargin) < expiry {
            print("Existing access token is still valid.")
            completion(true, nil)
            return
        }
        
        // Prepare the token request
        guard let url = URL(string: CogniteConfig.tokenURL) else {
            print("Invalid Token URL.")
            completion(false, NSError(domain: "CogniteAPI", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid Token URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set Content-Type header
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Prepare the body with client credentials
        let bodyParameters = [
            "client_id": CogniteConfig.clientID,
            "scope": CogniteConfig.tokenScopes,
            "client_secret": CogniteConfig.clientSecret,
            "grant_type": "client_credentials"
        ]
        
        // Encode body parameters
        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                                       .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        print("Sending authentication request with body: \(bodyString)")
        
        // Create data task with explicit type annotations in closure
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                print("Authentication request error: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type during authentication.")
                completion(false, NSError(domain: "CogniteAPI", code: 101, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
                return
            }
            
            let statusCode = httpResponse.statusCode
            print("Authentication response status code: \(statusCode)")
            
            guard (200...299).contains(statusCode) else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Authentication failed with body: \(responseBody)")
                    completion(false, NSError(domain: "CogniteAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Token request failed with status code \(statusCode): \(responseBody)"]))
                } else {
                    print("Authentication failed with no response body.")
                    completion(false, NSError(domain: "CogniteAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Token request failed with status code \(statusCode)"]))
                }
                return
            }
            
            do {
                guard let data = data else {
                    print("No data received during authentication.")
                    completion(false, NSError(domain: "CogniteAPI", code: 102, userInfo: [NSLocalizedDescriptionKey: "No data received from token endpoint"]))
                    return
                }
                
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                self?.accessToken = tokenResponse.access_token
                self?.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                print("Authentication successful. Access Token acquired.")
                completion(true, nil)
            } catch {
                print("Error decoding token response: \(error.localizedDescription)")
                if let responseBody = String(data: data ?? Data(), encoding: .utf8) {
                    print("Response Body: \(responseBody)")
                }
                completion(false, error)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Create Time Series Batch Method
    /// Creates multiple model instances (time series) in Cognite Data Fusion in a single API call.
    /// If any time series already exist, they will be ignored.
    /// - Parameters:
    ///   - definitions: An array of `TimeSeriesDefinition` containing externalId, name, type, and description.
    ///   - token: The access token for authentication.
    ///   - completion: Completion handler with a success flag and optional error.
    func createTimeSeriesBatch(instanceSpace: String, definitions: [TimeSeriesDefinition], token: String, completion: @escaping (Bool, Error?) -> Void) {
        // Construct the URL for creating model instances
        guard let url = URL(string: "\(CogniteConfig.baseURL)/api/v1/projects/\(CogniteConfig.project)/models/instances") else {
            print("Invalid URL for creating model instances.")
            completion(false, NSError(domain: "CogniteAPI", code: 200, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for creating model instances"]))
            return
        }
        
        // Prepare the payload with all definitions
        let items = definitions.map { definition -> [String: Any] in
            return [
                "space": instanceSpace,
                "externalId": definition.externalId,
                "instanceType": "node",
                "sources": [
                    [
                        "properties": [
                            "isStep": false,
                            "name": definition.name,
                            "type": definition.type,
                            "unit": [
                                "space": "cdf_cdm_units",
                                "externalId": definition.unit
                            ]
                        ],
                        "source": [
                            "space": "cdf_cdm",
                            "externalId": "CogniteTimeSeries",
                            "version": "v1",
                            "type": "view"
                        ]
                    ]
                ]
            ]
        }
        
        let payload: [String: Any] = ["items": items]
        
        // Serialize the payload to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Failed to serialize model instances payload to JSON.")
            completion(false, NSError(domain: "CogniteAPI", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize model instances payload to JSON"]))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // Use accessToken here
        request.httpBody = jsonData
        
        print("Creating \(definitions.count) time series in batch.")
        
        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                print("Batch creation error: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // Ensure response is HTTPURLResponse and handle status codes
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type during batch creation.")
                completion(false, NSError(domain: "CogniteAPI", code: 202, userInfo: [NSLocalizedDescriptionKey: "Invalid response type during batch creation"]))
                return
            }
            
            let statusCode = httpResponse.statusCode
            print("Batch creation response status code: \(statusCode)")
            
            guard (200...299).contains(statusCode) else {
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    print("Batch creation failed with body: \(responseBody)")
                    completion(false, NSError(domain: "CogniteAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Batch creation failed with status code \(statusCode): \(responseBody)"]))
                } else {
                    print("Batch creation failed with no response body.")
                    completion(false, NSError(domain: "CogniteAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Batch creation failed with status code \(statusCode)"]))
                }
                return
            }
            
            // Optionally, parse the response to check for partial successes or specific errors
            // For simplicity, assume all items are created successfully or already exist
            
            print("Successfully created \(definitions.count) time series in batch.")
            completion(true, nil)
        }
        
        task.resume()
    }
    
    // MARK: - Upload Batch Method (Simplified without Retry Logic)
    /// Uploads a batch of data points to a specific time series in Cognite Data Fusion.
    /// - Parameters:
    ///   - externalId: The externalId of the time series.
    ///   - datapoints: An array of `CDFDataPoint` representing the data to upload.
    ///   - token: The access token for authentication.
    ///   - completion: Completion handler with a success flag and optional error.
    func uploadBatch(instanceSpace: String, externalId: String, datapoints: [CDFDataPoint], token: String, completion: @escaping (Bool, Error?) -> Void) {
        // Construct the URL for the data points upload endpoint
        guard let url = URL(string: "\(CogniteConfig.baseURL)/api/v1/projects/\(CogniteConfig.project)/timeseries/data") else {
            print("Invalid URL for data points upload.")
            completion(false, NSError(domain: "CogniteAPI", code: 300, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for data points upload"]))
            return
        }

        // Prepare the payload wrapped inside "items" array
        let payload: [String: Any] = [
            "items": [
                [
                    "instanceId": [
                        "space": instanceSpace,
                        "externalId": externalId
                    ],
                    "datapoints": datapoints.map { ["timestamp": $0.timestamp, "value": $0.value] }
                ]
            ]
        ]

        // Serialize the payload to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            print("Failed to serialize data points to JSON.")
            completion(false, NSError(domain: "CogniteAPI", code: 301, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize data points to JSON"]))
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        print("Uploading batch to time series: \(externalId), number of datapoints: \(datapoints.count)")

        // Execute the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle errors
            if let error = error {
                print("Upload batch error for \(externalId): \(error.localizedDescription)")
                completion(false, error)
                return
            }

            // Ensure response is HTTPURLResponse and handle status codes
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type during batch upload for \(externalId).")
                completion(false, NSError(domain: "CogniteAPI", code: 303, userInfo: [NSLocalizedDescriptionKey: "Invalid response type during batch upload"]))
                return
            }

            let statusCode = httpResponse.statusCode

            if (200...299).contains(statusCode) {
                print("Successfully uploaded batch to time series: \(externalId)")
                completion(true, nil)
            } else {
                // Handle errors without retrying
                let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                print("Failed to upload batch for \(externalId). Status Code: \(statusCode). Response: \(responseBody)")
                completion(false, NSError(domain: "CogniteAPI", code: 305, userInfo: [NSLocalizedDescriptionKey: "Failed to upload data points, status code: \(statusCode)"]))
            }
        }

        task.resume()
    }
    
    // MARK: - Convert Health Data to CDFTimeSeries Method
    /// Converts HealthData into an array of CDFTimeSeries objects.
    /// - Parameter healthData: The HealthData object containing various health metrics.
    /// - Returns: An array of CDFTimeSeries ready for upload.
    func convertHealthDataToCDFTimeSeries(healthData: HealthData) -> [CDFTimeSeries] {
        var timeSeriesArray: [CDFTimeSeries] = []
        
        // Helper function to create CDFDataPoints from CodableQuantitySample
        func createDataPoints(from samples: [CodableQuantitySample]) -> [CDFDataPoint] {
            return samples.map { sample in
                CDFDataPoint(
                    timestamp: Int64(sample.startDate.timeIntervalSince1970 * 1000), // Convert to milliseconds
                    value: sample.value
                )
            }
        }
        
        // Helper function to create CDFDataPoints from CodableCategorySample
        func createDataPoints(from samples: [CodableCategorySample]) -> [CDFDataPoint] {
            return samples.map { sample in
                CDFDataPoint(
                    timestamp: Int64(sample.startDate.timeIntervalSince1970 * 1000), // Convert to milliseconds
                    value: Double(sample.value) // Assign appropriate numeric value based on category
                )
            }
        }
        
        // Heart Rates
        if !healthData.heartRates.isEmpty {
            let dataPoints = createDataPoints(from: healthData.heartRates)
            let timeSeries = CDFTimeSeries(
                externalId: "heart_rate",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Heart Rate Variability
        if !healthData.hrv.isEmpty {
            let dataPoints = createDataPoints(from: healthData.hrv)
            let timeSeries = CDFTimeSeries(
                externalId: "hrv",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Steps - Raw
        if !healthData.steps.isEmpty {
            let dataPoints = createDataPoints(from: healthData.steps)
            let timeSeries = CDFTimeSeries(
                externalId: "steps_raw",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Steps - Per Minute
        if !healthData.stepsMinute.isEmpty {
            let dataPoints = createDataPoints(from: healthData.stepsMinute)
            let timeSeries = CDFTimeSeries(
                externalId: "steps_minute",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Steps - Hourly
        if !healthData.stepsHourly.isEmpty {
            let dataPoints = createDataPoints(from: healthData.stepsHourly)
            let timeSeries = CDFTimeSeries(
                externalId: "steps_hourly",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Steps - Daily
        if !healthData.stepsDaily.isEmpty {
            let dataPoints = createDataPoints(from: healthData.stepsDaily)
            let timeSeries = CDFTimeSeries(
                externalId: "steps_daily",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Sleep Analysis (if applicable)
//        if !healthData.sleep.isEmpty {
//            let dataPoints = createDataPoints(from: healthData.sleep)
//            let timeSeries = CDFTimeSeries(
//                externalId: "sleep_analysis",
//                datapoints: dataPoints
//            )
//            timeSeriesArray.append(timeSeries)
//        }
        
        // Active Energy Burned - Raw
        if !healthData.activeEnergyBurned.isEmpty {
            let dataPoints = createDataPoints(from: healthData.activeEnergyBurned)
            let timeSeries = CDFTimeSeries(
                externalId: "active_energy_burned_raw",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Active Energy Burned - Per Minute
        if !healthData.activeEnergyBurnedMinute.isEmpty {
            let dataPoints = createDataPoints(from: healthData.activeEnergyBurnedMinute)
            let timeSeries = CDFTimeSeries(
                externalId: "active_energy_burned_minute",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Active Energy Burned - Hourly
        if !healthData.activeEnergyBurnedHourly.isEmpty {
            let dataPoints = createDataPoints(from: healthData.activeEnergyBurnedHourly)
            let timeSeries = CDFTimeSeries(
                externalId: "active_energy_burned_hourly",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Active Energy Burned - Daily
        if !healthData.activeEnergyBurnedDaily.isEmpty {
            let dataPoints = createDataPoints(from: healthData.activeEnergyBurnedDaily)
            let timeSeries = CDFTimeSeries(
                externalId: "active_energy_burned_daily",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Walking + Running Distance - Raw
        if !healthData.walkingRunningDistance.isEmpty {
            let dataPoints = createDataPoints(from: healthData.walkingRunningDistance)
            let timeSeries = CDFTimeSeries(
                externalId: "walking_running_distance_raw",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Walking + Running Distance - Per Minute
        if !healthData.walkingRunningDistanceMinute.isEmpty {
            let dataPoints = createDataPoints(from: healthData.walkingRunningDistanceMinute)
            let timeSeries = CDFTimeSeries(
                externalId: "walking_running_distance_minute",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Walking + Running Distance - Hourly
        if !healthData.walkingRunningDistanceHourly.isEmpty {
            let dataPoints = createDataPoints(from: healthData.walkingRunningDistanceHourly)
            let timeSeries = CDFTimeSeries(
                externalId: "walking_running_distance_hourly",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Walking + Running Distance - Daily
        if !healthData.walkingRunningDistanceDaily.isEmpty {
            let dataPoints = createDataPoints(from: healthData.walkingRunningDistanceDaily)
            let timeSeries = CDFTimeSeries(
                externalId: "walking_running_distance_daily",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Flights Climbed - Raw
        if !healthData.flightsClimbed.isEmpty {
            let dataPoints = createDataPoints(from: healthData.flightsClimbed)
            let timeSeries = CDFTimeSeries(
                externalId: "flights_climbed_raw",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Flights Climbed - Per Minute
        if !healthData.flightsClimbedMinute.isEmpty {
            let dataPoints = createDataPoints(from: healthData.flightsClimbedMinute)
            let timeSeries = CDFTimeSeries(
                externalId: "flights_climbed_minute",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Flights Climbed - Hourly
        if !healthData.flightsClimbedHourly.isEmpty {
            let dataPoints = createDataPoints(from: healthData.flightsClimbedHourly)
            let timeSeries = CDFTimeSeries(
                externalId: "flights_climbed_hourly",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        // Flights Climbed - Daily
        if !healthData.flightsClimbedDaily.isEmpty {
            let dataPoints = createDataPoints(from: healthData.flightsClimbedDaily)
            let timeSeries = CDFTimeSeries(
                externalId: "flights_climbed_daily",
                datapoints: dataPoints
            )
            timeSeriesArray.append(timeSeries)
        }
        
        return timeSeriesArray
    }
    
    // MARK: - Upload Health Data Method
    /// Uploads health data to Cognite Data Fusion with progress tracking.
    /// - Parameters:
    ///   - healthData: The serialized health data to upload.
    ///   - progressHandler: Closure to report upload progress (uploadedBatches, totalBatches).
    ///   - completion: Completion handler with a success flag and optional error.
    func uploadHealthData(
        healthData: HealthData,
        progressHandler: @escaping (Int, Int) -> Void,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        print("Starting uploadHealthData...")
        authenticate { [weak self] success, error in
            guard success, let self = self, let token = self.accessToken else {
                print("Authentication failed during uploadHealthData.")
                completion(false, error ?? NSError(domain: "CogniteAPI", code: 102, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"]))
                return
            }

            print("Authentication successful. Proceeding to create time series.")
            
            // Define all time series definitions with appropriate units
            let modelInstanceDefinitions: [TimeSeriesDefinition] = [
                // Heart
                TimeSeriesDefinition(
                    externalId: "heart_rate",
                    name: "Heart Rate",
                    type: "numeric",
                    description: "Heart rate data from HealthKit.",
                    unit: "frequency:per-min" // Number per Minute
                ),
                TimeSeriesDefinition(
                    externalId: "hrv",
                    name: "Heart Rate Variability",
                    type: "numeric",
                    description: "Heart rate variability data from HealthKit.",
                    unit: "time:millisec" // Millisecond
                ),
                
                // Steps
                TimeSeriesDefinition(
                    externalId: "steps_raw",
                    name: "Steps Raw",
                    type: "numeric",
                    description: "Raw steps data from HealthKit.",
                    unit: "dimensionless:num" // Number
                ),
                TimeSeriesDefinition(
                    externalId: "steps_minute",
                    name: "Steps Per Minute",
                    type: "numeric",
                    description: "Per minute aggregated steps data from HealthKit.",
                    unit: "frequency:per-min" // Number per Minute
                ),
                TimeSeriesDefinition(
                    externalId: "steps_hourly",
                    name: "Steps Hourly",
                    type: "numeric",
                    description: "Hourly aggregated steps data from HealthKit.",
                    unit: "frequency:num-per-hr" // Number per Hour
                ),
                TimeSeriesDefinition(
                    externalId: "steps_daily",
                    name: "Steps Daily",
                    type: "numeric",
                    description: "Daily aggregated steps data from HealthKit.",
                    unit: "dimensionless:num" // Number
                ),
                
                // Active Energy Burned
                TimeSeriesDefinition(
                    externalId: "active_energy_burned_raw",
                    name: "Active Energy Burned Raw",
                    type: "numeric",
                    description: "Raw active energy burned data from HealthKit.",
                    unit: "energy:kilocal" // Kilocalorie
                ),
                TimeSeriesDefinition(
                    externalId: "active_energy_burned_minute",
                    name: "Active Energy Burned Per Minute",
                    type: "numeric",
                    description: "Per minute aggregated active energy burned data from HealthKit.",
                    unit: "energy:kilocal"
                ),
                TimeSeriesDefinition(
                    externalId: "active_energy_burned_hourly",
                    name: "Active Energy Burned Hourly",
                    type: "numeric",
                    description: "Hourly aggregated active energy burned data from HealthKit.",
                    unit: "energy:kilocal"
                ),
                TimeSeriesDefinition(
                    externalId: "active_energy_burned_daily",
                    name: "Active Energy Burned Daily",
                    type: "numeric",
                    description: "Daily aggregated active energy burned data from HealthKit.",
                    unit: "energy:kilocal" // Kilocalorie
                ),
                
                // Walking + Running Distance
                TimeSeriesDefinition(
                    externalId: "walking_running_distance_raw",
                    name: "Walking Running Distance Raw",
                    type: "numeric",
                    description: "Raw walking and running distance data from HealthKit.",
                    unit: "length:m"
                ),
                TimeSeriesDefinition(
                    externalId: "walking_running_distance_minute",
                    name: "Walking Running Distance Per Minute",
                    type: "numeric",
                    description: "Per minute aggregated walking and running distance data from HealthKit.",
                    unit: "length:m"
                ),
                TimeSeriesDefinition(
                    externalId: "walking_running_distance_hourly",
                    name: "Walking Running Distance Hourly",
                    type: "numeric",
                    description: "Hourly aggregated walking and running distance data from HealthKit.",
                    unit: "length:m"
                ),
                TimeSeriesDefinition(
                    externalId: "walking_running_distance_daily",
                    name: "Walking Running Distance Daily",
                    type: "numeric",
                    description: "Daily aggregated walking and running distance data from HealthKit.",
                    unit: "length:m"
                ),
                
                // Flights Climbed
                TimeSeriesDefinition(
                    externalId: "flights_climbed_raw",
                    name: "Flights Climbed Raw",
                    type: "numeric",
                    description: "Raw flights climbed data from HealthKit.",
                    unit: "dimensionless:num" // Number
                ),
                TimeSeriesDefinition(
                    externalId: "flights_climbed_minute",
                    name: "Flights Climbed Per Minute",
                    type: "numeric",
                    description: "Per minute aggregated flights climbed data from HealthKit.",
                    unit: "frequency:per-min" // Number per Minute
                ),
                TimeSeriesDefinition(
                    externalId: "flights_climbed_hourly",
                    name: "Flights Climbed Hourly",
                    type: "numeric",
                    description: "Hourly aggregated flights climbed data from HealthKit.",
                    unit: "frequency:num-per-hr" // Number per Hour
                ),
                TimeSeriesDefinition(
                    externalId: "flights_climbed_daily",
                    name: "Flights Climbed Daily",
                    type: "numeric",
                    description: "Daily aggregated flights climbed data from HealthKit.",
                    unit: "dimensionless:num" // Number
                )
            ]

            
            let instanceSpace = CogniteConfig.space

            // Ensure all time series are created in a single batch
            self.createTimeSeriesBatch(instanceSpace: instanceSpace, definitions: modelInstanceDefinitions, token: token) { success, error in
                if !success {
                    print("Failed to create time series in batch.")
                    completion(false, error)
                    return
                }

                print("All required time series are ensured to exist. Proceeding to upload data.")

                // Convert health data to CDFTimeSeries
                let timeSeriesArray = self.convertHealthDataToCDFTimeSeries(healthData: healthData)
                let batchSize = 10000 // Adjust batch size as necessary

                var uploadError: Error?
                var uploadedBatches = 0
                let totalUploadBatches = timeSeriesArray.reduce(0) { $0 + Int(ceil(Double($1.datapoints.count) / Double(batchSize))) }

                print("Total time series to upload: \(timeSeriesArray.count)")
                print("Total upload batches to process: \(totalUploadBatches)")

                func uploadNextTimeSeries(index: Int) {
                    if index >= timeSeriesArray.count {
                        if let error = uploadError {
                            print("uploadHealthData completed with errors.")
                            completion(false, error)
                        } else {
                            print("uploadHealthData completed successfully.")
                            completion(true, nil)
                        }
                        return
                    }

                    let timeSeries = timeSeriesArray[index]
                    let batches = stride(from: 0, to: timeSeries.datapoints.count, by: batchSize).map {
                        Array(timeSeries.datapoints[$0..<min($0 + batchSize, timeSeries.datapoints.count)])
                    }

                    func uploadBatch(batchIndex: Int) {
                        if batchIndex >= batches.count {
                            uploadNextTimeSeries(index: index + 1)
                            return
                        }

                        let batch = batches[batchIndex]
                        self.uploadBatch(instanceSpace: instanceSpace, externalId: timeSeries.externalId, datapoints: batch, token: token) { success, error in
                            if !success {
                                print("Failed to upload batch for time series: \(timeSeries.externalId)")
                                uploadError = error
                            } else {
                                uploadedBatches += 1
                                print("Successfully uploaded batch \(uploadedBatches) of \(totalUploadBatches) for time series: \(timeSeries.externalId)")
                                progressHandler(uploadedBatches, totalUploadBatches)
                            }

                            uploadBatch(batchIndex: batchIndex + 1)
                        }
                    }

                    uploadBatch(batchIndex: 0)
                }

                uploadNextTimeSeries(index: 0)
            }
        }
    }
}
