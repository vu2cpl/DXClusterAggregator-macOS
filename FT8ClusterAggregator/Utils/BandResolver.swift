import Foundation

/// Maps a frequency in MHz to a ham-radio band designation (ADIF style: "20M", "40M", etc.)
struct BandResolver {
    struct BandRange {
        let name: String
        let lowMHz: Double
        let highMHz: Double
    }

    static let bands: [BandRange] = [
        BandRange(name: "2190M", lowMHz: 0.135, highMHz: 0.138),
        BandRange(name: "630M",  lowMHz: 0.472, highMHz: 0.479),
        BandRange(name: "160M",  lowMHz: 1.8,   highMHz: 2.0),
        BandRange(name: "80M",   lowMHz: 3.5,   highMHz: 4.0),
        BandRange(name: "60M",   lowMHz: 5.25,  highMHz: 5.45),
        BandRange(name: "40M",   lowMHz: 7.0,   highMHz: 7.3),
        BandRange(name: "30M",   lowMHz: 10.1,  highMHz: 10.15),
        BandRange(name: "20M",   lowMHz: 14.0,  highMHz: 14.35),
        BandRange(name: "17M",   lowMHz: 18.068, highMHz: 18.168),
        BandRange(name: "15M",   lowMHz: 21.0,  highMHz: 21.45),
        BandRange(name: "12M",   lowMHz: 24.89, highMHz: 24.99),
        BandRange(name: "10M",   lowMHz: 28.0,  highMHz: 29.7),
        BandRange(name: "6M",    lowMHz: 50.0,  highMHz: 54.0),
        BandRange(name: "4M",    lowMHz: 70.0,  highMHz: 70.5),
        BandRange(name: "2M",    lowMHz: 144.0, highMHz: 148.0),
        BandRange(name: "1.25M", lowMHz: 222.0, highMHz: 225.0),
        BandRange(name: "70CM",  lowMHz: 420.0, highMHz: 450.0),
        BandRange(name: "33CM",  lowMHz: 902.0, highMHz: 928.0),
        BandRange(name: "23CM",  lowMHz: 1240.0, highMHz: 1300.0),
    ]

    static func band(fromMHz freq: Double) -> String? {
        for b in bands where freq >= b.lowMHz && freq <= b.highMHz {
            return b.name
        }
        return nil
    }

    static func band(fromHz freq: UInt64) -> String? {
        band(fromMHz: Double(freq) / 1_000_000.0)
    }
}
