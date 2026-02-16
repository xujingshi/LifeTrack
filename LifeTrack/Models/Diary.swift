import Foundation

// MARK: - 日记模型
struct Diary: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String?
    let content: String
    let mood: Int?
    let weather: String?
    let diaryDate: String
    let createdAt: String
    let updatedAt: String
    let images: [DiaryImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case content
        case mood
        case weather
        case diaryDate = "diary_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case images
    }

    var moodEmoji: String {
        guard let mood = mood else { return "" }
        switch mood {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "😊"
        case 5: return "😄"
        default: return ""
        }
    }

    var weatherIcon: String {
        guard let weather = weather else { return "" }
        switch weather {
        case "sunny": return "☀️"
        case "cloudy": return "☁️"
        case "rainy": return "🌧️"
        case "snowy": return "❄️"
        case "windy": return "💨"
        default: return weather
        }
    }
}

// MARK: - 日记图片模型
struct DiaryImage: Codable, Identifiable {
    let id: Int
    let diaryId: Int
    let imagePath: String
    let sortOrder: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case diaryId = "diary_id"
        case imagePath = "image_path"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    var imageURL: URL? {
        URL(string: "\(APIConfig.baseURL)/uploads/\(imagePath.components(separatedBy: "/").last ?? "")")
    }
}

// MARK: - 请求模型
struct CreateDiaryRequest: Codable {
    let title: String?
    let content: String
    let mood: Int?
    let weather: String?
    let diaryDate: String

    enum CodingKeys: String, CodingKey {
        case title
        case content
        case mood
        case weather
        case diaryDate = "diary_date"
    }
}

struct UpdateDiaryRequest: Codable {
    let title: String?
    let content: String?
    let mood: Int?
    let weather: String?
    let diaryDate: String?

    enum CodingKeys: String, CodingKey {
        case title
        case content
        case mood
        case weather
        case diaryDate = "diary_date"
    }
}
