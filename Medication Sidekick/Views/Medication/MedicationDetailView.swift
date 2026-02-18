//
//  MedicationDetailView.swift
//  Medication Sidekick
//
//  Created by Alan Ashton on 2026-02-16.
//

//
//  MedicationDetailView.swift
//  Medication Sidekick
//

import SwiftUI
import SwiftData

struct MedicationDetailView: View {
    
    // MARK: - Dependencies
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var navigationRouter: NavigationRouter
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Input
    let medication: Medication
    
    // MARK: - State
    @State private var showDeleteConfirm = false
    
    var body: some View {
        
        VStack(spacing: 16) {
            
            // MARK: - Header Card
            VStack(alignment: .leading, spacing: 8) {
                Text(medication.name)
                    .font(.title2.bold())
                
                Text("\(medication.dosage) mg")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(themeManager.selectedTheme.toolbarBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            
            // MARK: - Schedules Section (placeholder for now)
            VStack(alignment: .leading, spacing: 8) {
                
                Text("Schedules")
                    .font(.headline)
                
                Text("No schedules yet")
                    .foregroundStyle(.secondary)
                
                Button {
                    // TODO: navigate to schedule creation
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
                .padding(.top, 4)
                
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(themeManager.selectedTheme.toolbarBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            
            Spacer()
            
        }
        .padding()
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        
        // MARK: - Toolbar
        .toolbar {
            
            // Edit (future)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    
                    Button {
                        // TODO: Edit flow
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        
        // MARK: - Delete Confirmation
        .alert("Delete Medication", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteMedication()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this medication?")
        }
    }
    
    // MARK: - Actions
    private func deleteMedication() {
        modelContext.delete(medication)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to delete medication: \(error)")
        }
    }
}


#if DEBUG
#Preview("Medication Detail") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Medication.self, configurations: config)
        let context = container.mainContext

        // Use shared preview data
        try? PreviewData.seed(into: context)

        // Fetch a sample medication
        let descriptor = FetchDescriptor<Medication>()
        let medications = try context.fetch(descriptor)
        let medication = medications.first!

        return NavigationStack {
            MedicationDetailView(medication: medication)
                .environmentObject(NavigationRouter())
                .environment(ThemeManager())
        }
        .modelContainer(container)
    } catch {
        fatalError("Failed to create model container: \(error)")
    }
}
#endif
