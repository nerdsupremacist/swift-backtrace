//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftLinuxBacktrace open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the SwiftLinuxBacktrace project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftLinuxBacktrace project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Linux)
import CBacktrace
import Glibc

typealias CBacktraceErrorCallback = @convention(c) (_ data: UnsafeMutableRawPointer?, _ msg: UnsafePointer<CChar>?, _ errnum: CInt) -> Void
typealias CBacktraceFullCallback = @convention(c) (_ data: UnsafeMutableRawPointer?, _ pc: UInt, _ filename: UnsafePointer<CChar>?, _ lineno: CInt, _ function: UnsafePointer<CChar>?) -> CInt
typealias CBacktraceSimpleCallback = @convention(c) (_ data: UnsafeMutableRawPointer?, _ pc: UInt) -> CInt
typealias CBacktraceSyminfoCallback = @convention(c) (_ data: UnsafeMutableRawPointer?, _ pc: UInt, _ filename: UnsafePointer<CChar>?, _ symval: UInt, _ symsize: UInt) -> Void

private let state = backtrace_create_state(CommandLine.arguments[0], /* BACKTRACE_SUPPORTS_THREADS */ 1, nil, nil)

private let fullCallback: CBacktraceFullCallback? = {
    _, pc, filename, lineno, function in

    var str = "0x"
    str.append(String(pc, radix: 16))
    if let function = function {
        str.append(", ")
        var fn = String(cString: function)
        if fn.hasPrefix("$s") || fn.hasPrefix("$S") {
            fn = _stdlib_demangleName(fn)
        }
        str.append(fn)
    }
    if let filename = filename {
        str.append(" at ")
        str.append(String(cString: filename))
        str.append(":")
        str.append(String(lineno))
    }
    str.append("\n")

    str.withCString { ptr in
        _ = withVaList([ptr]) { vaList in
            vfprintf(stderr, "%s", vaList)
            fflush(stderr)
        }
    }
    return 0
}

private let errorCallback: CBacktraceErrorCallback? = {
    _, msg, _ in
    if let msg = msg {
        _ = withVaList([msg]) { vaList in
            vfprintf(stderr, "%s\n", vaList)
            fflush(stderr)
        }
    }
}

public enum Backtrace {
    public static func install() {
        self.setupHandler(signal: SIGILL) { _ in
            backtrace_full(state, /* skip */ 0, fullCallback, errorCallback, nil)
        }
    }

    @available(*, deprecated, message: "This method will be removed in the next major version.")
    public static func print() {
        backtrace_full(state, /* skip */ 0, fullCallback, errorCallback, nil)
    }

    private static func setupHandler(signal: Int32, handler: @escaping @convention(c) (CInt) -> Void) {
        typealias sigaction_t = sigaction
        let sa_flags = CInt(SA_NODEFER) | CInt(bitPattern: CUnsignedInt(SA_RESETHAND))
        var sa = sigaction_t(__sigaction_handler: unsafeBitCast(handler, to: sigaction.__Unnamed_union___sigaction_handler.self),
                             sa_mask: sigset_t(),
                             sa_flags: sa_flags,
                             sa_restorer: nil)
        withUnsafePointer(to: &sa) { ptr -> Void in
            sigaction(signal, ptr, nil)
        }
    }
}

#else
public enum Backtrace {
    public static func install() {}

    @available(*, deprecated, message: "This method will be removed in the next major version.")
    public static func print() {}
}
#endif
