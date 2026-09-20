import SwiftUI
import Charts
import DaybookCore
#if os(iOS)
import HealthKit

final class HealthReader {
    private let store = HKHealthStore()
    func load() async throws -> [HealthDay] {
        guard HKHealthStore.isHealthDataAvailable() else { throw DaybookError.invalid("Health data is unavailable on this device.") }
        let steps = HKQuantityType(.stepCount), energy = HKQuantityType(.activeEnergyBurned)
        let sleep = HKCategoryType(.sleepAnalysis), workouts = HKWorkoutType.workoutType()
        try await store.requestAuthorization(toShare: [], read: [steps, energy, sleep, workouts])
        let calendar = Calendar.current; let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -7, to: today)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        let sleepSamples = try await samples(type: sleep, predicate: predicate).compactMap { $0 as? HKCategorySample }
        let valid = sleepSamples.filter { [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue].contains($0.value) }
        // Prefer Watch-generated samples; otherwise pick one source rather than adding incompatible trackers.
        let watch = valid.filter { ($0.device?.model ?? "").localizedCaseInsensitiveContains("watch") }
        let pool = watch.isEmpty ? valid : watch
        let grouped = Dictionary(grouping: pool) { $0.sourceRevision.source.bundleIdentifier }
        let selected = grouped.sorted { a, b in
            let aApple = a.key.hasPrefix("com.apple"), bApple = b.key.hasPrefix("com.apple")
            if aApple != bApple { return aApple }
            return a.value.count > b.value.count
        }.first?.value ?? []
        let sleeping = HealthMath.sleepByWakeDate(selected.map { TimeSpan(start: $0.startDate, end: $0.endDate) }, calendar: calendar)
        let workoutSamples = try await samples(type: workouts, predicate: predicate)
        var days: [HealthDay] = []
        for offset in (-6)...0 {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            let stepCount = try await sum(type: steps, unit: .count(), from: day, to: next)
            let kcal = try await sum(type: energy, unit: .kilocalorie(), from: day, to: next)
            let intervals = workoutSamples.filter { $0.startDate < next && $0.endDate > day }.map { TimeSpan(start: max(day, $0.startDate), end: min(next, $0.endDate)) }
            days.append(HealthDay(date: day, steps: stepCount, sleepHours: sleeping[day], activeKcal: kcal,
                                  workoutMinutes: intervals.isEmpty ? nil : HealthMath.duration(intervals) / 60))
        }
        return days
    }
    private func samples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            store.execute(HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, result, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result ?? []) }
            })
        }
    }
    private func sum(type: HKQuantityType, unit: HKUnit, from: Date, to: Date) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
            store.execute(HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                // Statistics queries report an empty day (including unreadable
                // records) as errorNoData. Preserve it as unknown, not zero, and
                // keep loading the other days and data types.
                if let error, (error as NSError).domain == HKErrorDomain,
                   (error as NSError).code == HKError.Code.errorNoData.rawValue {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
                }
            })
        }
    }
}
#endif

struct HealthView: View {
    @EnvironmentObject var model: AppModel
    @State private var loading = false
    var body: some View {
        Page {
            PageHeader(eyebrow: "HEALTH / YOUR RHYTHM", title: "Room to recharge.", detail: "Sleep and movement, without turning your body into a score.")
            Panel {
                Label("Apple Health", systemImage: "heart.fill").foregroundStyle(Theme.green).font(.headline)
                #if os(iOS)
                Text("Read your last seven days of sleep, steps, activity energy and workouts. You choose what to share in Apple's permission sheet.").font(.subheadline).foregroundStyle(Theme.muted)
                Button(loading ? "Reading Health…" : "Connect / refresh Apple Health") {
                    guard model.requireLiveData() else { return }
                    loading = true
                    Task {
                        do {
                            let days = try await HealthReader().load()
                            model.update { state in
                                let replaced = Set(days.map(\.id))
                                state.health = (state.health.filter { !replaced.contains($0.id) } + days).sorted { $0.date < $1.date }
                                state.healthUpdatedAt = Date()
                            }
                        }
                        catch { model.error = error.localizedDescription }
                        loading = false
                    }
                }.buttonStyle(.borderedProminent).disabled(loading)
                #else
                Text("Connect on your iPhone. This Mac preview cannot access your phone's HealthKit store; no health data is simulated.").font(.subheadline).foregroundStyle(Theme.muted)
                #endif
                if let date = model.snapshot.healthUpdatedAt { Text("Last query: \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Theme.muted) }
                Text("India supports this HealthKit workflow. Data availability still depends on device permissions and what your Watch records.").font(.caption).foregroundStyle(Theme.muted)
            }
            let days = Array(model.snapshot.health.suffix(7))
            if days.contains(where: { $0.sleepHours != nil }) {
                Panel {
                    SectionLabel(text: "Recorded sleep · hours")
                    Chart(days.filter { $0.sleepHours != nil }) { day in
                        BarMark(x: .value("Wake day", day.date, unit: .day), y: .value("Hours", day.sleepHours!)).foregroundStyle(Theme.green).cornerRadius(4)
                    }.frame(height: 170)
                    Text("One preferred source; overlapping stages are merged. Sessions are assigned to their wake date and may include naps.").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            if days.contains(where: { $0.steps != nil }) {
                Panel {
                    SectionLabel(text: "Daily steps")
                    Chart(days.filter { $0.steps != nil }) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Steps", day.steps!)).foregroundStyle(Theme.ochre).cornerRadius(4)
                    }.frame(height: 170)
                }
            }
            if !days.isEmpty {
                ForEach(days.reversed()) { day in
                    Panel {
                        Text(day.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                        HStack {
                            Text(day.activeKcal.map { "\(Int($0)) active kcal" } ?? "Energy unavailable")
                            Spacer()
                            Text(day.workoutMinutes.map { "\(Int($0)) workout min" } ?? "Workouts unavailable")
                        }.font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            }
            if days.allSatisfy({ $0.steps == nil && $0.sleepHours == nil && $0.activeKcal == nil && $0.workoutMinutes == nil }) {
                ContentUnavailableView("Your health, on your terms", systemImage: "moon.stars", description: Text("No accessible records yet. Missing records can mean unavailable data or limited permissions; they do not mean zero activity."))
            }
        }
    }
}
