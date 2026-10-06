import Foundation
import MotionatorKit

let code = MotionatorCommand.run(
    Array(CommandLine.arguments.dropFirst()),
    out: { print($0) },
    err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
exit(code)
