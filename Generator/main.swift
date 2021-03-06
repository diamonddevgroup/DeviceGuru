#!/usr/bin/env swift

import Foundation

// MARK: - Functions

struct Model: Hashable {

    let version: Double
    let enumCase: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(enumCase)
    }

    static func ==(lhs: Model, rhs: Model) -> Bool {
        return lhs.enumCase == rhs.enumCase
    }
}

func getUniqueSortedModels(havingPrefix: String, from deviceList: [String: [String: AnyObject]]) -> [Model] {

    let filteredDict = deviceList.filter { $0.key.hasPrefix(havingPrefix) }
    let models: [Model] = filteredDict.values.compactMap {

        guard let version = $0["version"] as? NSNumber, let enumCase = $0["enum"] as? String else {
            print("Can't create model from this: \($0)")
            return nil
        }
        return Model(version: version.doubleValue, enumCase: enumCase)
    }

    // Get the unique models i.e. ignore models which has same enum, we don't want same enum twice in case that
    // will cause compiler error
    let sortedModels = models.sorted { $0.version < $1.version }
    var modelSet = Set<Model>()
    sortedModels.forEach { modelSet.insert($0) }
    return modelSet.sorted { $0.version < $1.version }
}

func readPropertyList() -> [String: [String: AnyObject]]? {
    var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml
    let plistPath: String = "GeneratorDeviceList.plist"
    let plistXML = FileManager.default.contents(atPath: plistPath)!
    do {//convert the data to a dictionary and handle errors.
        let plistData = try PropertyListSerialization.propertyList(from: plistXML,
                                                               options: .mutableContainersAndLeaves,
                                                               format: &propertyListFormat)
        guard let dictionary = plistData as? [String: [String: AnyObject]] else {
            print("Unable to convert plist into dictionary.")
            return nil
        }
        return dictionary
    } catch {
        print("Error reading plist: \(error), format: \(propertyListFormat)")
        return nil
    }
}


func normalizedEnum(_ enumCase: String) -> String {
    let lowerCasedEnum = enumCase.lowercased()
    if lowerCasedEnum == "iphone" || lowerCasedEnum == "ipad" || lowerCasedEnum == "ipod" {
        return "iP" + lowerCasedEnum.dropFirst(2)
    } else if lowerCasedEnum == "x86_64" || lowerCasedEnum == "i386" {
        return lowerCasedEnum + "_simulator"
    } else {
        return lowerCasedEnum
    }
}

func main() {

    guard let generatorDeviceList = readPropertyList() else { return }
    let tabSpacing = "    "
    let unknownCase = "unknownDevice"
    let unknownIphoneCase = "unknownIphone"
    let unknownIpodCase = "unknownIpod"
    let unknownIpadCase = "unknownIpad"
    let unknownAppleWatchCase = "unknownAppleWatch"
    let unknownAppleTVCase = "unknownAppleTV"


    var deviceList: [String: [String: AnyObject]] = [:]

    // DeviceList.plist generation
    generatorDeviceList.keys.sorted().forEach { hardwareKey in
        var valueDict = generatorDeviceList[hardwareKey]
        valueDict?.removeValue(forKey: "enum")
        deviceList[hardwareKey] = valueDict
    }
    let dirPath = "../Source/"

    print("Writing plist.")
    guard (deviceList as NSDictionary).write(toFile: "\(dirPath)DeviceList.plist", atomically: true) else {
        print("Unable to write the plist.")
        return
    }
    print("Plist created.")


    // Enum file generatoin
    let enumFile = "Hardware.swift"

    var enumString = "\npublic enum Hardware {\n"
        + "\n\(tabSpacing)case \(unknownCase)"
        + "\n\(tabSpacing)case \(unknownIphoneCase)"
        + "\n\(tabSpacing)case \(unknownIpodCase)"
        + "\n\(tabSpacing)case \(unknownIpadCase)"
        + "\n\(tabSpacing)case \(unknownAppleWatchCase)"
        + "\n\(tabSpacing)case \(unknownAppleTVCase)\n"

        + "\n\(tabSpacing)case simulator\n"

    // Get devices by device type
    let iPhoneModels = getUniqueSortedModels(havingPrefix: "iPhone", from: generatorDeviceList)
    iPhoneModels.forEach {
        let swiftEnumCase = normalizedEnum($0.enumCase)
        enumString += "\n\(tabSpacing)case \(swiftEnumCase)"
    }
    enumString += "\n"

    let iPodModels = getUniqueSortedModels(havingPrefix: "iPod", from: generatorDeviceList)
    iPodModels.forEach {
        let swiftEnumCase = normalizedEnum($0.enumCase)
        enumString += "\n\(tabSpacing)case \(swiftEnumCase)"
    }
    enumString += "\n"

    let iPadModels = getUniqueSortedModels(havingPrefix: "iPad", from: generatorDeviceList)
    iPadModels.forEach {
        let swiftEnumCase = normalizedEnum($0.enumCase)
        enumString += "\n\(tabSpacing)case \(swiftEnumCase)"
    }
    enumString += "\n"

    let watchModels = getUniqueSortedModels(havingPrefix: "Watch", from: generatorDeviceList)
    watchModels.forEach {
        let swiftEnumCase = normalizedEnum($0.enumCase)
        enumString += "\n\(tabSpacing)case \(swiftEnumCase)"
    }
    enumString += "\n"

    let appleTVModels = getUniqueSortedModels(havingPrefix: "AppleTV", from: generatorDeviceList)
    appleTVModels.forEach {
        let swiftEnumCase = normalizedEnum($0.enumCase)
        enumString += "\n\(tabSpacing)case \(swiftEnumCase)"
    }

    print("Creating \(enumFile)")
    do {
        let enumFileConent = enumString + "\n}"
        try enumFileConent.write(toFile: dirPath + enumFile, atomically: true, encoding: .utf8)
        print("Created \(enumFile)")
    } catch {
        print("Unable to create \(enumFile)")
        return
    }

    // Extension file generation
    var hardwareFuncContent = ""
    let extensionFile = "DeviceGuru+Extension.swift"
    generatorDeviceList.keys.sorted().forEach { hardwareKey in
        let valueDict = generatorDeviceList[hardwareKey]
        guard let enumCase = valueDict?["enum"] as? String else {
            print("case not present of key \(hardwareKey)")
            return
        }

        let enumCaseString = normalizedEnum(enumCase)
        hardwareFuncContent += "\n\(tabSpacing)\(tabSpacing)if (hardware == \"\(hardwareKey)\") { return .\(enumCaseString) }"
    }


    print("Creating \(extensionFile)")
    do {
        let extensionFileConent = "\npublic extension DeviceGuru {"
            + "\n\(tabSpacing)/// This method returns the Hardware enum depending upon hardware string\n"
            + "\(tabSpacing)///\n"
            + "\(tabSpacing)///\n"
            + "\(tabSpacing)/// - returns: `Hardware` type of the device\n"
            + "\(tabSpacing)///\n"
            + "\(tabSpacing)func hardware() -> Hardware {"
            + "\n\(tabSpacing)\(tabSpacing)let hardware = hardwareString()\n"
            + hardwareFuncContent
            + "\n\n"
            + "\(tabSpacing)\(tabSpacing)//log message that your device is not present in the list\n"
            + "\(tabSpacing)\(tabSpacing)logMessage(hardware)\n"
            + "\(tabSpacing)\(tabSpacing)if (hardware.hasPrefix(\"iPhone\")) { return .\(unknownIphoneCase) }\n"
            + "\(tabSpacing)\(tabSpacing)if (hardware.hasPrefix(\"iPod\")) { return .\(unknownIpodCase) }\n"
            + "\(tabSpacing)\(tabSpacing)if (hardware.hasPrefix(\"iPad\")) { return .\(unknownIpadCase) }\n"
            + "\(tabSpacing)\(tabSpacing)if (hardware.hasPrefix(\"Watch\")) { return .\(unknownAppleWatchCase) }\n"
            + "\(tabSpacing)\(tabSpacing)if (hardware.hasPrefix(\"AppleTV\")) { return .\(unknownAppleTVCase) }\n\n"
            + "\(tabSpacing)\(tabSpacing)return .unknownDevice\n"
            + "\(tabSpacing)}\n"
            + "}\n"
        try extensionFileConent.write(toFile: dirPath + extensionFile, atomically: true, encoding: .utf8)
        print("Created \(extensionFile)")
    } catch {
        print("Unable to create \(extensionFile)")
        return
    }

}

// MARK: - Calling Main

main()
