import Foundation

enum MappingMergePolicy: String {
    case keepFirst = "first"
    case keepLast = "last"
}

enum MappingSafety {
    static func dictionary<Key: Hashable, Value>(
        pairs: [(Key, Value)],
        logPrefix: String,
        keyName: String,
        countLabel: String,
        screen: String,
        mergePolicy: MappingMergePolicy,
        keyFormatter: (Key) -> String = { String(describing: $0) }
    ) -> [Key: Value] {
        var dictionary: [Key: Value] = [:]
        var duplicateCounts: [Key: Int] = [:]

        for (key, value) in pairs {
            if dictionary[key] != nil {
                duplicateCounts[key, default: 1] += 1
                if mergePolicy == .keepLast {
                    dictionary[key] = value
                }
            } else {
                dictionary[key] = value
            }
        }

        logDuplicates(
            duplicateCounts,
            logPrefix: logPrefix,
            keyName: keyName,
            countLabel: countLabel,
            screen: screen,
            mergePolicy: mergePolicy,
            keyFormatter: keyFormatter
        )

        return dictionary
    }

    static func orderedUniqueElements<Key: Hashable>(
        _ elements: [Key],
        logPrefix: String,
        keyName: String,
        countLabel: String,
        screen: String,
        keyFormatter: (Key) -> String = { String(describing: $0) }
    ) -> [Key] {
        var orderedUniqueElements: [Key] = []
        var seenKeys = Set<Key>()
        var duplicateCounts: [Key: Int] = [:]

        for element in elements {
            if seenKeys.insert(element).inserted {
                orderedUniqueElements.append(element)
            } else {
                duplicateCounts[element, default: 1] += 1
            }
        }

        logDuplicates(
            duplicateCounts,
            logPrefix: logPrefix,
            keyName: keyName,
            countLabel: countLabel,
            screen: screen,
            mergePolicy: .keepFirst,
            keyFormatter: keyFormatter
        )

        return orderedUniqueElements
    }

    static func logDuplicateKeys<Key: Hashable>(
        _ keys: [Key],
        logPrefix: String,
        keyName: String,
        countLabel: String,
        screen: String,
        keyFormatter: (Key) -> String = { String(describing: $0) }
    ) {
        var duplicateCounts: [Key: Int] = [:]
        for key in keys {
            duplicateCounts[key, default: 0] += 1
        }

        logDuplicates(
            duplicateCounts.filter { $0.value > 1 },
            logPrefix: logPrefix,
            keyName: keyName,
            countLabel: countLabel,
            screen: screen,
            mergePolicy: nil,
            keyFormatter: keyFormatter
        )
    }

    private static func logDuplicates<Key: Hashable>(
        _ duplicateCounts: [Key: Int],
        logPrefix: String,
        keyName: String,
        countLabel: String,
        screen: String,
        mergePolicy: MappingMergePolicy?,
        keyFormatter: (Key) -> String
    ) {
        guard duplicateCounts.isEmpty == false else { return }

        let sortedDuplicates = duplicateCounts.sorted { lhs, rhs in
            keyFormatter(lhs.key) < keyFormatter(rhs.key)
        }

        for (key, count) in sortedDuplicates {
            let formattedKey = keyFormatter(key)
            print(
                "\(logPrefix) duplicate \(keyName) detected " +
                "\(keyName)=\(formattedKey) " +
                "\(countLabel)=\(count) " +
                "screen=\(screen)"
            )

            guard let mergePolicy else { continue }
            print(
                "\(logPrefix) merged duplicate \(keyName) entries using \(mergePolicy.rawValue) policy " +
                "\(keyName)=\(formattedKey) " +
                "screen=\(screen)"
            )
        }
    }
}
