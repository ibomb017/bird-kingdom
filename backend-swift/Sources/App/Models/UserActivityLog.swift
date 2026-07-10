import Fluent
import Vapor

final class UserActivityLog: Model, Content {
    static let schema = "user_activity_logs"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int64?
    
    @Field(key: "user_id")
    var userId: Int64
    
    @Field(key: "activity_date")
    var activityDate: Date
    
    @Field(key: "last_login_time")
    var lastActiveAt: Date
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(userId: Int64, activityDate: Date, lastActiveAt: Date) {
        self.userId = userId
        self.activityDate = activityDate
        self.lastActiveAt = lastActiveAt
    }
}
