import Foundation

struct MyNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var date: Date
    var reminderDate: Date? // New property for reminder
}
