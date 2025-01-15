// ./ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var statusMessage = "Press a button to fetch health data."
    @State private var showingSettings = false
    
    // Add @AppStorage properties
    @AppStorage("cdf_clusterName") private var clusterName: String = ""
    @AppStorage("cdf_project") private var project: String = ""
    @AppStorage("cdf_tenantID") private var tenantID: String = ""
    @AppStorage("cdf_clientID") private var clientID: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Upload to CDF Section
                    
                    VStack(spacing: 10) {
                        // Upload to CDF Button at the top
                        Button(action: {
                            Task {
                                await startUploading()
                            }
                        }) {
                            Text(viewModel.isUploading ? "Uploading..." : "Upload to CDF")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(canUpload() ? Color.green : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!canUpload() || viewModel.isUploading)
                        
                        // Uploading Indicators
                        if viewModel.isUploading {
                            VStack(spacing: 5) {
                                ProgressView(value: viewModel.uploadProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .padding([.horizontal])
                                
                                Text(viewModel.uploadCurrentStep)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(viewModel.uploadStatus)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                            .animation(.easeInOut, value: viewModel.isUploading)
                        } else if viewModel.uploadStatus != "Ready to upload." && !viewModel.uploadStatus.isEmpty {
                            Text(viewModel.uploadStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding([.horizontal])
                                .transition(.opacity)
                                .animation(.easeInOut, value: viewModel.uploadStatus)
                        }
                    }
                    
                    // MARK: - Status Message
                    Text(statusMessage)
                        .font(.headline)
                        .padding()
                    
                    // MARK: - Fetching Indicators
                    if viewModel.isFetching {
                        ProgressView(value: viewModel.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                        
                        Text(viewModel.currentDataType)
                            .font(.subheadline)
                            .padding()
                    }
                    
                    // MARK: - Display Fetch Results Persistently
                    if !viewModel.fetchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.fetchResults.keys.sorted(), id: \.self) { key in
                                if let count = viewModel.fetchResults[key] {
                                    Text("\(key): \(count) data points fetched.")
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    }
                    
                    // MARK: - Fetch Buttons
                    VStack(spacing: 10) {
                        Button(action: {
                            Task {
                                await startFetching(with: .past5Years)
                            }
                        }) {
                            Text(viewModel.isFetching ? "Fetching..." : "Fetch Last 5 Years")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(viewModel.isFetching ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.isFetching)
                        
                        Button(action: {
                            Task {
                                await startFetching(with: .lastMonth)
                            }
                        }) {
                            Text(viewModel.isFetching ? "Fetching..." : "Fetch Last Month")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(viewModel.isFetching ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.isFetching)
                        
                        Button(action: {
                            Task {
                                await startFetching(with: .lastWeek)
                            }
                        }) {
                            Text(viewModel.isFetching ? "Fetching..." : "Fetch Last Week")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .background(viewModel.isFetching ? Color.gray : Color.blue)
                                .cornerRadius(8)
                        }
                        .disabled(viewModel.isFetching)
                    }
                    
                }
                .padding()
            }
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.fetchError != nil || viewModel.uploadError != nil },
                set: { _ in
                    viewModel.fetchError = nil
                    viewModel.uploadError = nil
                }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.fetchError?.localizedDescription ?? viewModel.uploadError?.localizedDescription ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarTitle("Health Data Uploader", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
            })
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    /// Initiates the fetching process based on the selected fetch option.
    /// - Parameter option: The selected fetch option.
    func startFetching(with option: FetchOption) async {
        await viewModel.fetchAllHealthData(startDate: option.startDate, endDate: option.endDate)
        
        if let error = viewModel.fetchError {
            statusMessage = "Error: \(error.localizedDescription)"
        } else {
            switch option {
            case .past5Years:
                statusMessage = "Past 5 years' data fetched successfully. Ready to upload."
            case .lastMonth:
                statusMessage = "Last month's data fetched successfully. Ready to upload."
            case .lastWeek:
                statusMessage = "Last week's data fetched successfully. Ready to upload."
            }
        }
    }
    
    /// Initiates the upload process to CDF.
    func startUploading() async {
        await viewModel.uploadDataToCDF()
        
        if let error = viewModel.uploadError {
            statusMessage = "Upload failed: \(error.localizedDescription)"
        } else {
            statusMessage = "Data uploaded to CDF successfully!"
        }
    }
    
    /// Determines if the upload button should be enabled.
    func canUpload() -> Bool {
        let cluster = !clusterName.isEmpty
        let project = !project.isEmpty
        let tenant = !tenantID.isEmpty
        let clientIDValid = !clientID.isEmpty
        let clientSecret = KeychainHelper.standard.read(service: "com.cognite.CDF", account: "clientSecret") != nil
        
        let canUpload = cluster && project && tenant && clientIDValid && clientSecret && !viewModel.fetchResults.isEmpty && viewModel.fetchError == nil && !viewModel.isUploading
        
        return canUpload
    }
    
    /// Defines the fetch options with corresponding date ranges.
    enum FetchOption {
        case past5Years
        case lastMonth
        case lastWeek
        
        var startDate: Date {
            switch self {
            case .past5Years:
                return Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date.distantPast
            case .lastMonth:
                return Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date.distantPast
            case .lastWeek:
                return Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date.distantPast
            }
        }
        
        var endDate: Date {
            return Date()
        }
    }
}
