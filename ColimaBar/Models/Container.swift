import Foundation

struct Container: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: String?

    var hostPorts: [Int] {
        guard let ports else { return [] }
        var seen = Set<Int>()
        var result: [Int] = []
        for segment in ports.split(separator: ",") {
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            guard let arrowIndex = trimmed.range(of: "->") else { continue }
            let hostSide = trimmed[..<arrowIndex.lowerBound]
            guard let colon = hostSide.lastIndex(of: ":") else { continue }
            let portString = hostSide[hostSide.index(after: colon)...]
            if let port = Int(portString), seen.insert(port).inserted {
                result.append(port)
            }
        }
        return result
    }

    var isRunning: Bool {
        status.lowercased().hasPrefix("up")
    }

    static func decodeList(from ndjson: String) -> [Container] {
        let decoder = JSONDecoder()
        return ndjson
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> Container? in
                guard let data = line.data(using: .utf8) else { return nil }
                guard let raw = try? decoder.decode(RawContainer.self, from: data) else {
                    return nil
                }
                return raw.normalized
            }
    }
}

// Docker emits Pascal-case keys; nerdctl emits lowercase. Both shapes decode
// into this struct and `normalized` picks whichever half is populated.
private struct RawContainer: Decodable {
    let ID: String?
    let Names: String?
    let Image: String?
    let Status: String?
    let Ports: String?

    let id: String?
    let names: String?
    let image: String?
    let status: String?
    let ports: String?

    var normalized: Container? {
        let identifier = ID ?? id
        let name = Names ?? names
        let img = Image ?? image
        let stat = Status ?? status
        guard let identifier, let name, let img, let stat else { return nil }
        return Container(
            id: identifier,
            name: name,
            image: img,
            status: stat,
            ports: (Ports ?? ports).flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
