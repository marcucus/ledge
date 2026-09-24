import Darwin
import Foundation

// MARK: — PollingSource

//
// CPU, RAM, and network are sampled only while the panel is open (2 Hz max).
// The module calls beginPolling()/endPolling() from its content view's
// onAppear/onDisappear hooks so no resources are consumed at rest.

/// Samples CPU, RAM, and network at a fixed interval when active.
final class PollingSource {
    var onCPU: ((CPUStats) -> Void)?
    var onRAM: ((RAMStats) -> Void)?
    var onNetwork: ((NetworkStats) -> Void)?

    private var timer: Timer?
    private var cpuHistory: [Double] = []
    private let historyMax = 30

    // Previous network byte counters for delta computation
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var prevSampleTime: Date = .init()

    /// Previous CPU tick counts for delta computation
    private var prevCPUTicks: [Int32] = []

    // MARK: — Lifecycle

    /// Start sampling at `interval` seconds (default 0.5 s = 2 Hz max).
    func beginPolling(interval: TimeInterval = 0.5) {
        guard timer == nil else { return }
        // Seed baseline counters so the first delta is meaningful
        seedNetworkCounters()
        seedCPUTicks()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func endPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: — Sample

    private func sample() {
        sampleCPU()
        sampleRAM()
        sampleNetwork()
    }

    // MARK: — CPU  (host_processor_info)

    private func seedCPUTicks() {
        prevCPUTicks = rawCPUTicks()
    }

    private func sampleCPU() {
        let current = rawCPUTicks()
        guard current.count == prevCPUTicks.count, !current.isEmpty else {
            prevCPUTicks = current
            return
        }

        var totalIdle = 0
        var totalActive = 0
        let stride = Int(CPU_STATE_MAX)

        for index in Swift.stride(from: 0, to: current.count, by: stride) {
            let maxIdx = index + Int(CPU_STATE_MAX) - 1
            guard maxIdx < current.count, maxIdx < prevCPUTicks.count else { break }
            let idle = Int(current[index + Int(CPU_STATE_IDLE)]) - Int(prevCPUTicks[index + Int(CPU_STATE_IDLE)])
            let user = Int(current[index + Int(CPU_STATE_USER)]) - Int(prevCPUTicks[index + Int(CPU_STATE_USER)])
            let system = Int(current[index + Int(CPU_STATE_SYSTEM)]) - Int(prevCPUTicks[index + Int(CPU_STATE_SYSTEM)])
            let nice = Int(current[index + Int(CPU_STATE_NICE)]) - Int(prevCPUTicks[index + Int(CPU_STATE_NICE)])
            totalIdle += max(0, idle)
            totalActive += max(0, user) + max(0, system) + max(0, nice)
        }

        prevCPUTicks = current
        let total = totalIdle + totalActive
        let usage = total > 0 ? Double(totalActive) / Double(total) : 0

        cpuHistory.append(usage)
        if cpuHistory.count > historyMax { cpuHistory.removeFirst() }
        onCPU?(CPUStats(usage: usage, history: cpuHistory))
    }

    private func rawCPUTicks() -> [Int32] {
        var cpuCount: natural_t = 0
        var infoPtr: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &infoPtr,
            &infoCount
        )
        guard result == KERN_SUCCESS, let ptr = infoPtr else { return [] }

        let ticks = Array(UnsafeBufferPointer(start: ptr, count: Int(infoCount)))
        let deallocSize = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: ptr)), deallocSize)
        return ticks
    }

    // MARK: — RAM  (vm_statistics64)

    private func sampleRAM() {
        var stats = vm_statistics64()
        // HOST_VM_INFO64_COUNT is the canonical count expected by the kernel
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, raw, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        onRAM?(RAMStats(used: min(used, total), total: total))
    }

    // MARK: — Network  (getifaddrs)

    private func seedNetworkCounters() {
        let (bytesIn, bytesOut) = readNetworkBytes()
        prevBytesIn = bytesIn
        prevBytesOut = bytesOut
        prevSampleTime = Date()
    }

    private func sampleNetwork() {
        let now = Date()
        let elapsed = now.timeIntervalSince(prevSampleTime)
        guard elapsed > 0 else { return }

        let (bytesIn, bytesOut) = readNetworkBytes()
        let rateIn = Double(bytesIn > prevBytesIn ? bytesIn - prevBytesIn : 0) / elapsed
        let rateOut = Double(bytesOut > prevBytesOut ? bytesOut - prevBytesOut : 0) / elapsed

        prevBytesIn = bytesIn
        prevBytesOut = bytesOut
        prevSampleTime = now

        onNetwork?(NetworkStats(bytesInPerSec: rateIn, bytesOutPerSec: rateOut))
    }

    private func readNetworkBytes() -> (UInt64, UInt64) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let start = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(start) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = start

        while let ifa = cursor {
            let flags = ifa.pointee.ifa_flags
            // Skip loopback and interfaces that are down
            let isLoopback = (flags & UInt32(IFF_LOOPBACK)) != 0
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let hasData = ifa.pointee.ifa_data != nil

            if !isLoopback, isUp, hasData,
               let data = ifa.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
            {
                totalIn += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }
}
