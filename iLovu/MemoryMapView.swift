// MemoryMapView.swift
// A map of everywhere your dates happened — one pin per Memory that captured a
// location at completion (Memory.latitude/longitude, stamped from a real GPS fix).
// Deepens the Memory Vault moat: a year of shared dates, plotted. Presented as a
// sheet from the Us tab; tapping a pin opens that memory. Reads MemoryStore only.

import SwiftUI
import MapKit

struct MemoryMapView: View {

    @Environment(MemoryStore.self) private var memoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMemory: Memory?

    private struct Pin: Identifiable {
        let id: UUID
        let memory: Memory
        let coordinate: CLLocationCoordinate2D
    }

    // Newest first, only memories that carry a coordinate.
    private var pins: [Pin] {
        memoryStore.sortedByDate.compactMap { memory in
            guard let lat = memory.latitude, let lng = memory.longitude else { return nil }
            return Pin(id: memory.id, memory: memory,
                       coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pins.isEmpty {
                    emptyState
                } else {
                    // .automatic frames all the pins on open.
                    Map(initialPosition: .automatic) {
                        ForEach(pins) { pin in
                            Annotation(pin.memory.cardTitle, coordinate: pin.coordinate) {
                                Button { selectedMemory = pin.memory } label: {
                                    Text(pin.memory.cardEmoji)
                                        .font(.system(size: 20))
                                        .frame(width: 40, height: 40)
                                        .background(Color.white, in: Circle())
                                        .overlay(Circle().stroke(Color.louvCoral, lineWidth: 2))
                                        .louvShadow()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Our Date Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.louvCoral)
                        .fontWeight(.semibold)
                }
            }
            .fullScreenCover(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory)
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            Color.blushCream.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("🗺️").font(.system(size: 48))
                Text("Your date map")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.deepRose)
                Text("Pins appear here as you complete dates with location turned on — a growing map of everywhere you've been together.")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
            }
        }
    }
}
