import Fluent
import Vapor

final class SystemConfig: Model, Content, @unchecked Sendable {
    static let schema = "system_config"

    @ID(custom: "id")
    var id: Int64?

    @Field(key: "config_key")
    var configKey: String

    @Field(key: "config_value")
    var configValue: String

    @OptionalField(key: "value_type")
    var valueType: String?

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "category")
    var category: String?

    @Field(key: "is_public")
    var isPublic: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }
}
