import Foundation

public func debugLog(function: StaticString = #function,
                     file: StaticString = #file,
                     line: UInt = #line,
                     error: Error? = nil,
                     _ items: Any..., separator: String = " ", terminator: String = "\n") {
    
    #if DEBUG
    Swift.print("\n⚠️")
    
    let thread = Thread.isMainThread ? "MainThread" : Thread.current.name ?? "Not MainThread"
    Swift.print("file \(file)")
    Swift.print("⌖ function \(function), line \(line) - ⚙ \(thread) \(Date())")
    
    if !items.isEmpty {
        Swift.print("🔍🔍🔍")
        items.forEach {
            debugPrint($0, separator: separator, terminator: terminator)
        }
    }
    Swift.print("🖕\n")
    #endif
}
