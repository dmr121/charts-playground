import SwiftUI

struct ContentView: View {
    @State private var data: [PairedPoint] = TwoLineData.sample

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TwoLineComparisonChart(data: data)
                    .frame(height: 300)
                    .padding(.horizontal)

                HStack {
                    Button("Randomize") {
                        // No animation: update immediately
                        data = TwoLineData.random(count: data.count)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Add Point") {
                        // No animation
                        data.append(PairedPoint(x: (data.last?.x ?? 0) + 1,
                                                y1: Double.random(in: 0...100),
                                                y2: Double.random(in: 0...100)))
                    }
                    .buttonStyle(.bordered)

                    Button("Remove Point") {
                        // No animation
                        if !data.isEmpty { _ = data.removeLast() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Two-Line Chart")
        }
    }
}

#Preview {
    ContentView()
}
