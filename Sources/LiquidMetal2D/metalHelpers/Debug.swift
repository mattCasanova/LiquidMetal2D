//
//  File.swift
//
//
//  Created by Matt Casanova on 3/2/21.
//

import Foundation

// swiftlint:disable identifier_name
#if DEBUG
func DebugPrint(_ format: String, _ args: CVarArg...) {
    print(String(format: format, args))
}

func DebugRun(_ toRun: () -> Void) {
    toRun()
}
#else
func DebugPrint(_ format: String, _ args: CVarArg...) {}
func DebugRun(_ toRun: () -> Void) {}
#endif
// swiftlint:enable identifier_name
