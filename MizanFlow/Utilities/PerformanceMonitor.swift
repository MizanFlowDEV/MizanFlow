import Foundation
import os

/// Performance monitoring utility
@MainActor
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = AppLogger.general
    private var metrics: [String: TimeInterval] = [:]
    
    private init() {}
    
    // MARK: - Timing Functions
    
    func startTiming(_ operation: String) -> Date {
        let startTime = Date()
        metrics[operation] = startTime.timeIntervalSince1970
        return startTime
    }
    
    func endTiming(_ operation: String, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        metrics[operation] = duration
        
        if duration > 1.0 {
            logger.warning("Slow operation detected: \(operation) took \(String(format: "%.2f", duration))s")
        } else {
            logger.debug("Operation \(operation) completed in \(String(format: "%.2f", duration))s")
        }
    }
    
    func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = startTiming(operation)
        defer {
            endTiming(operation, startTime: startTime)
        }
        return try block()
    }
    
    func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = startTiming(operation)
        defer {
            endTiming(operation, startTime: startTime)
        }
        return try await block()
    }
    
    // MARK: - Memory Monitoring
    
    func logMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        let count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) { memoryPointer in
            return memoryPointer.withMemoryRebound(to: integer_t.self, capacity: 1) { intPointer in
                var mutableCount = count
                return task_info(mach_task_self_,
                                task_flavor_t(MACH_TASK_BASIC_INFO),
                                intPointer,
                                &mutableCount)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(memoryInfo.resident_size) / 1024.0 / 1024.0 // Convert to MB
            logger.info("Memory usage: \(String(format: "%.2f", usedMemory)) MB")
        }
    }
    
    // MARK: - View Load Tracking
    
    func trackViewLoad(_ viewName: String) {
        _ = startTiming("view_load_\(viewName)")
        // End timing will be called when view appears
        logger.debug("View \(viewName) started loading")
    }
    
    func endViewLoad(_ viewName: String, startTime: Date) {
        endTiming("view_load_\(viewName)", startTime: startTime)
    }
    
    // MARK: - Core Data Performance
    
    func trackCoreDataOperation(_ operation: String, duration: TimeInterval) {
        if duration > 0.5 {
            logger.warning("Slow Core Data operation: \(operation) took \(String(format: "%.2f", duration))s")
        }
        metrics["coredata_\(operation)"] = duration
    }
    
    // MARK: - Get Metrics
    
    func getMetrics() -> [String: TimeInterval] {
        return metrics
    }
    
    func getMetric(_ operation: String) -> TimeInterval? {
        return metrics[operation]
    }
    
    func resetMetrics() {
        metrics.removeAll()
    }
}

// MARK: - View Performance Modifier

import SwiftUI

struct PerformanceTrackingModifier: ViewModifier {
    let viewName: String
    @State private var loadStartTime: Date?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                loadStartTime = PerformanceMonitor.shared.startTiming("view_\(viewName)")
            }
            .onDisappear {
                if let startTime = loadStartTime {
                    PerformanceMonitor.shared.endTiming("view_\(viewName)", startTime: startTime)
                }
            }
    }
}

extension View {
    func trackPerformance(_ viewName: String) -> some View {
        modifier(PerformanceTrackingModifier(viewName: viewName))
    }
}

