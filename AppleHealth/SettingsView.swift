import SwiftUI

struct SettingsView: View {
    // AppStorage properties to persist configuration
    @AppStorage("cdf_clusterName") private var storedClusterName: String = "api"
    @AppStorage("cdf_project") private var storedProject: String = "andershaf"
    @AppStorage("cdf_tenantID") private var storedTenantID: String = "5409fe5e-39ad-4448-90ad-6688455011bf"
    @AppStorage("cdf_clientID") private var storedClientID: String = "d2d8009c-6c86-4dee-8633-588ec4f07027"
    @AppStorage("cdf_space") private var storedSpace: String = "space"
    @AppStorage("enableAutoSync") private var enableAutoSync: Bool = false


    // State variables for user input
    @State private var clusterNameInput: String = ""
    @State private var projectInput: String = ""
    @State private var tenantIDInput: String = ""
    @State private var clientIDInput: String = ""
    @State private var clientSecretInput: String = ""
    @State private var spaceInput: String = "" // Updated State Variable

    @Environment(\.presentationMode) var presentationMode

    private let keychainService = "com.cognite.CDF"
    private let keychainAccount = "clientSecret"

    var body: some View {
        NavigationView {
            Form {
                // Authentication Section
                Section(header: Text("Authentication")) {
                    // Cluster Name Field
                    HStack(alignment: .top) {
                        Text("Cluster Name")
                            .frame(width: 150, alignment: .leading)
                        TextField("Enter Cluster Name", text: $clusterNameInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Project Name Field
                    HStack(alignment: .top) {
                        Text("Project Name")
                            .frame(width: 150, alignment: .leading)
                        TextField("Enter Project Name", text: $projectInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Tenant ID Field
                    HStack(alignment: .top) {
                        Text("Tenant ID")
                            .frame(width: 150, alignment: .leading)
                        TextField("Enter Tenant ID", text: $tenantIDInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Client ID Field
                    HStack(alignment: .top) {
                        Text("Client ID")
                            .frame(width: 150, alignment: .leading)
                        TextField("Enter Client ID", text: $clientIDInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    // Client Secret Field
                    HStack(alignment: .top) {
                        Text("Client Secret")
                            .frame(width: 150, alignment: .leading)
                        SecureField("••••••••••", text: $clientSecretInput)
                            .onAppear {
                                if let data = KeychainHelper.standard.read(service: keychainService, account: keychainAccount),
                                   let secret = String(data: data, encoding: .utf8) {
                                    self.clientSecretInput = "" // Do not prepopulate for security
                                }
                            }
                            .onChange(of: clientSecretInput) { newValue in
                                if let data = newValue.data(using: .utf8) {
                                    KeychainHelper.standard.save(data, service: keychainService, account: keychainAccount)
                                }
                            }
                    }
                }

                // Data Section
                Section(header: Text("Data")) {
                    // Instance Space Field
                    HStack(alignment: .top) {
                        Text("Instance Space")
                            .frame(width: 150, alignment: .leading)
                        TextField("Enter Instance Space", text: $spaceInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                Section(header: Text("Background Sync")) {
                    Toggle(isOn: $enableAutoSync) {
                        Text("Automatic sync (every hour)")
                    }
                    .onChange(of: enableAutoSync) { value in
                        if value {
                            BackgroundSyncManager.shared.scheduleSync()
                        } else {
                            BackgroundSyncManager.shared.cancelSync()
                        }
                    }
                }
            }
            .navigationBarTitle("CDF Settings", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                // Initialize state variables with stored values
                self.clusterNameInput = storedClusterName.isEmpty ? "" : storedClusterName
                self.projectInput = storedProject.isEmpty ? "" : storedProject
                self.tenantIDInput = storedTenantID.isEmpty ? "" : storedTenantID
                self.clientIDInput = storedClientID.isEmpty ? "" : storedClientID
                self.spaceInput = storedSpace.isEmpty ? "" : storedSpace // Initialize Instance Space

                // Optionally, you can decide whether to prepopulate clientSecretInput
                // For security reasons, it's often better to leave it empty
                self.clientSecretInput = ""
            }
        }
    }

    /// Saves the user input to AppStorage and Keychain.
    private func saveSettings() {
        // Update AppStorage with user inputs or retain existing values if inputs are empty
        if !clusterNameInput.trimmingCharacters(in: .whitespaces).isEmpty {
            storedClusterName = clusterNameInput.trimmingCharacters(in: .whitespaces)
        }

        if !projectInput.trimmingCharacters(in: .whitespaces).isEmpty {
            storedProject = projectInput.trimmingCharacters(in: .whitespaces)
        }

        if !tenantIDInput.trimmingCharacters(in: .whitespaces).isEmpty {
            storedTenantID = tenantIDInput.trimmingCharacters(in: .whitespaces)
        }

        if !clientIDInput.trimmingCharacters(in: .whitespaces).isEmpty {
            storedClientID = clientIDInput.trimmingCharacters(in: .whitespaces)
        }

        if !spaceInput.trimmingCharacters(in: .whitespaces).isEmpty {
            storedSpace = spaceInput.trimmingCharacters(in: .whitespaces)
        }
    }
}
