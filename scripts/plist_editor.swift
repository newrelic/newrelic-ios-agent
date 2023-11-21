#!/usr/bin/swift

import Foundation

let plistPath = "../Test Harness/NRTestApp/NRAPI-Info.plist"
var keyToChange = "NRAPIKey"

let namedArguments = UserDefaults.standard

guard let valueToAdd = namedArguments.string(forKey: "valueToAdd") else {
    print("No value passed")
    exit(1)
}
print("Value is: \(valueToAdd)")

if let newKeyToChange = namedArguments.string(forKey: "keyToChange") {
    keyToChange = newKeyToChange
}
print("Key is: \(keyToChange)")


guard let plistData = FileManager.default.contents(atPath: plistPath) else {
    print("Error: Unable to read .plist file.")
    exit(1)
}

guard var plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
    print("Error: Unable to parse .plist file.")
    exit(1)
}

if let value = plistDict[keyToChange] {
    if value as! String == valueToAdd {
        print("Key \(keyToChange) value is already \(valueToAdd)")
        exit(0)
    }
    print("Warning: Key \(keyToChange) is already \(value) in .plist file. Overwriting value.")
}

plistDict[keyToChange] = valueToAdd

guard let newPlistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) else {
    print("Error: Unable to serialize updated .plist dictionary.")
    exit(1)
}

do {
    try newPlistData.write(to: URL(fileURLWithPath: plistPath))
    print("Success: Added key \(keyToChange) with value \(valueToAdd) to .plist file.")
} catch {
    print("Error: Unable to write updated .plist file.")
    exit(1)
}
