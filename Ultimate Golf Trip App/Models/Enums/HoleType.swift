import Foundation

enum HoleType: String, Codable {
    case par3 = "Par 3"
    case par4 = "Par 4"
    case par5 = "Par 5"

    var par: Int {
        switch self {
        case .par3: return 3
        case .par4: return 4
        case .par5: return 5
        }
    }

    init(par: Int) {
        switch par {
        case 3: self = .par3
        case 5: self = .par5
        default: self = .par4
        }
    }
}
