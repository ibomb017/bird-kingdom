import SwiftUI
import Combine

/// 应用语言类型
enum AppLanguage: String, CaseIterable {
    case zh = "zh"           // 简体中文
    case zhHant = "zh-Hant" // 繁体中文
    case en = "en"           // English
    case ja = "ja"           // 日本語
    case es = "es"           // Español
    case ko = "ko"           // 한국어
    
    var displayName: String {
        switch self {
        case .zh: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .es: return "Español"
        case .ko: return "한국어"
        }
    }
    
    var icon: String {
        switch self {
        case .zh: return "🇨🇳"
        case .zhHant: return "🇭🇰"
        case .en: return "🇺🇸"
        case .ja: return "🇯🇵"
        case .es: return "🇪🇸"
        case .ko: return "🇰🇷"
        }
    }
}

/// 全局语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "app_language")
            Bundle.setLanguage(current.rawValue)
            objectWillChange.send()
        }
    }
    
    /// 语音识别标签文件名（根据语言切换）
    var voiceLabelsFileName: String {
        (current == .zh || current == .zhHant) ? "labels_zh" : "labels"
    }
    
    private init() {
        let lang: AppLanguage
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let savedLang = AppLanguage(rawValue: saved) {
            lang = savedLang
        } else {
            // 跟随系统语言
            let systemLang = Locale.current.language.languageCode?.identifier ?? "zh"
            if systemLang.hasPrefix("en") {
                lang = .en
            } else if systemLang.hasPrefix("ja") {
                lang = .ja
            } else if systemLang.hasPrefix("es") {
                lang = .es
            } else if systemLang.hasPrefix("ko") {
                lang = .ko
            } else if systemLang.hasPrefix("zh-Hant") || systemLang.hasPrefix("zh-HK") || systemLang.hasPrefix("zh-TW") {
                lang = .zhHant
            } else {
                lang = .zh
            }
        }
        self.current = lang
        Bundle.setLanguage(lang.rawValue)
    }
    
    var isEnglish: Bool { current != .zh && current != .zhHant }
    var isChinese: Bool { current == .zh || current == .zhHant }
}

// MARK: - 本地化字符串表
/// 使用: L10n.tabHome / L10n.settingsLanguage 等
struct L10n {
    private static var lang: AppLanguage { LanguageManager.shared.current }
    private static var isEn: Bool { lang == .en }
    
    // MARK: - TabBar
    static var tabHome: String { NSLocalizedString("tabHome", comment: "") }
    static var tabEncyclopedia: String { NSLocalizedString("tabEncyclopedia", comment: "") }
    static var tabForum: String { NSLocalizedString("tabForum", comment: "") }
    static var tabProfile: String { NSLocalizedString("tabProfile", comment: "") }
    
    // MARK: - 通用
    static var cancel: String { NSLocalizedString("cancel", comment: "") }
    static var confirm: String { NSLocalizedString("confirm", comment: "") }
    static var delete: String { NSLocalizedString("delete", comment: "") }
    static var edit: String { NSLocalizedString("edit", comment: "") }
    static var save: String { NSLocalizedString("save", comment: "") }
    static var retry: String { NSLocalizedString("retry", comment: "") }
    static var close: String { NSLocalizedString("close", comment: "") }
    static var done: String { NSLocalizedString("done", comment: "") }
    static var loading: String { NSLocalizedString("loading", comment: "") }
    static var noData: String { NSLocalizedString("noData", comment: "") }
    static var success: String { NSLocalizedString("success", comment: "") }
    static var failed: String { NSLocalizedString("failed", comment: "") }
    static var back: String { NSLocalizedString("back", comment: "") }
    static var more: String { NSLocalizedString("more", comment: "") }
    static var all: String { NSLocalizedString("all", comment: "") }
    static var search: String { NSLocalizedString("search", comment: "") }
    static var share: String { NSLocalizedString("share", comment: "") }
    static var settings: String { NSLocalizedString("settings", comment: "") }
    
    // MARK: - 首页
    static var myBirds: String { NSLocalizedString("myBirds", comment: "") }
    static var addBird: String { NSLocalizedString("addBird", comment: "") }
    static var birdLog: String { NSLocalizedString("birdLog", comment: "") }
    static var allLogs: String { NSLocalizedString("allLogs", comment: "") }
    static var writeLog: String { NSLocalizedString("writeLog", comment: "") }
    static var weight: String { NSLocalizedString("weight", comment: "") }
    static var weightRecord: String { NSLocalizedString("weightRecord", comment: "") }
    static var healthRecords: String { NSLocalizedString("healthRecords", comment: "") }
    static var expense: String { NSLocalizedString("expense", comment: "") }
    static var reminder: String { NSLocalizedString("reminder", comment: "") }
    static var noBirdsYet: String { NSLocalizedString("noBirdsYet", comment: "") }
    static var noBirdsHint: String { NSLocalizedString("noBirdsHint", comment: "") }
    static var birdName: String { NSLocalizedString("birdName", comment: "") }
    static var birdSpecies: String { NSLocalizedString("birdSpecies", comment: "") }
    static var birdGender: String { NSLocalizedString("birdGender", comment: "") }
    static var birdBirthday: String { NSLocalizedString("birdBirthday", comment: "") }
    static var male: String { NSLocalizedString("male", comment: "") }
    static var female: String { NSLocalizedString("female", comment: "") }
    static var unknownGender: String { NSLocalizedString("unknownGender", comment: "") }
    static var birdDetails: String { NSLocalizedString("birdDetails", comment: "") }
    static var today: String { NSLocalizedString("today", comment: "") }
    static var yesterday: String { NSLocalizedString("yesterday", comment: "") }
    static var daysAgo: String { NSLocalizedString("daysAgo", comment: "") }
    static var deleteLog: String { NSLocalizedString("deleteLog", comment: "") }
    static var deleteLogConfirm: String { NSLocalizedString("deleteLogConfirm", comment: "") }
    static var allBirds: String { NSLocalizedString("allBirds", comment: "") }
    static var sharedBirds: String { NSLocalizedString("sharedBirds", comment: "") }
    
    // MARK: - 百科
    static var encyclopedia: String { NSLocalizedString("encyclopedia", comment: "") }
    static var birdEncyclopedia: String { NSLocalizedString("birdEncyclopedia", comment: "") }
    static var smartDiagnosis: String { NSLocalizedString("smartDiagnosis", comment: "") }
    static var foodQuery: String { NSLocalizedString("foodQuery", comment: "") }
    static var symptomQuery: String { NSLocalizedString("symptomQuery", comment: "") }
    static var voiceRecognition: String { NSLocalizedString("voiceRecognition", comment: "") }
    static var startRecording: String { NSLocalizedString("startRecording", comment: "") }
    static var recording: String { NSLocalizedString("recording", comment: "") }
    static var recordingHint: String { NSLocalizedString("recordingHint", comment: "") }
    static var analyzing: String { NSLocalizedString("analyzing", comment: "") }
    static var recognitionResult: String { NSLocalizedString("recognitionResult", comment: "") }
    static var confidence: String { NSLocalizedString("confidence", comment: "") }
    static var candidateSpecies: String { NSLocalizedString("candidateSpecies", comment: "") }
    static var technicalParams: String { NSLocalizedString("technicalParams", comment: "") }
    static var inferenceEngine: String { NSLocalizedString("inferenceEngine", comment: "") }
    static var inferenceTime: String { NSLocalizedString("inferenceTime", comment: "") }
    static var recordDuration: String { NSLocalizedString("recordDuration", comment: "") }
    static var sampleRate: String { NSLocalizedString("sampleRate", comment: "") }
    static var peakFrequency: String { NSLocalizedString("peakFrequency", comment: "") }
    static var reRecognize: String { NSLocalizedString("reRecognize", comment: "") }
    static var noMicDetected: String { NSLocalizedString("noMicDetected", comment: "") }
    static var noMicHint: String { NSLocalizedString("noMicHint", comment: "") }
    static var micPermissionNeeded: String { NSLocalizedString("micPermissionNeeded", comment: "") }
    static var micPermissionDenied: String { NSLocalizedString("micPermissionDenied", comment: "") }
    static var recordTooShort: String { NSLocalizedString("recordTooShort", comment: "") }
    static var seconds: String { NSLocalizedString("seconds", comment: "") }
    static var onDeviceInference: String { NSLocalizedString("onDeviceInference", comment: "") }
    static var birdSpeciesCount: String { NSLocalizedString("birdSpeciesCount", comment: "") }
    static var holdToRecord: String { NSLocalizedString("holdToRecord", comment: "") }
    
    // MARK: - 我的页面
    static var profile: String { NSLocalizedString("profile", comment: "") }
    static var myMessages: String { NSLocalizedString("myMessages", comment: "") }
    static var shareInvitations: String { NSLocalizedString("shareInvitations", comment: "") }
    static var myPosts: String { NSLocalizedString("myPosts", comment: "") }
    static var myFavorites: String { NSLocalizedString("myFavorites", comment: "") }
    static var myFollowing: String { NSLocalizedString("myFollowing", comment: "") }
    static var myFollowers: String { NSLocalizedString("myFollowers", comment: "") }
    static var birthdayCelebration: String { NSLocalizedString("birthdayCelebration", comment: "") }
    static var recycleBin: String { NSLocalizedString("recycleBin", comment: "") }
    static var clearCache: String { NSLocalizedString("clearCache", comment: "") }
    static var themeSetting: String { NSLocalizedString("themeSetting", comment: "") }
    static var languageSetting: String { NSLocalizedString("languageSetting", comment: "") }
    static var accountSecurity: String { NSLocalizedString("accountSecurity", comment: "") }
    static var aboutUs: String { NSLocalizedString("aboutUs", comment: "") }
    static var logout: String { NSLocalizedString("logout", comment: "") }
    static var vipMember: String { NSLocalizedString("vipMember", comment: "") }
    static var notLoggedIn: String { NSLocalizedString("notLoggedIn", comment: "") }
    static var tapToLogin: String { NSLocalizedString("tapToLogin", comment: "") }
    static var editProfile: String { NSLocalizedString("editProfile", comment: "") }
    static var nickname: String { NSLocalizedString("nickname", comment: "") }
    static var bio: String { NSLocalizedString("bio", comment: "") }
    static var changeAvatar: String { NSLocalizedString("changeAvatar", comment: "") }
    static var myOrders: String { NSLocalizedString("myOrders", comment: "") }
    static var deleteAccount: String { NSLocalizedString("deleteAccount", comment: "") }
    static var logoutConfirm: String { NSLocalizedString("logoutConfirm", comment: "") }
    static var selectLanguage: String { NSLocalizedString("selectLanguage", comment: "") }
    static var languageChangeHint: String { NSLocalizedString("languageChangeHint", comment: "") }
    
    // MARK: - 登录
    static var login: String { NSLocalizedString("login", comment: "") }
    static var register: String { NSLocalizedString("register", comment: "") }
    static var phone: String { NSLocalizedString("phone", comment: "") }
    static var password: String { NSLocalizedString("password", comment: "") }
    static var verificationCode: String { NSLocalizedString("verificationCode", comment: "") }
    static var getCode: String { NSLocalizedString("getCode", comment: "") }
    static var agreeTerms: String { NSLocalizedString("agreeTerms", comment: "") }
    
    // MARK: - 鸟鸟庆生
    static var splashTitle: String { NSLocalizedString("splashTitle", comment: "") }
    static var orderStatus: String { NSLocalizedString("orderStatus", comment: "") }
    static var pending: String { NSLocalizedString("pending", comment: "") }
    static var approved: String { NSLocalizedString("approved", comment: "") }
    static var rejected: String { NSLocalizedString("rejected", comment: "") }
    static var refunded: String { NSLocalizedString("refunded", comment: "") }
    
    // MARK: - 体重 & 花销
    static var weightUnit: String { NSLocalizedString("weightUnit", comment: "") }
    static var addWeight: String { NSLocalizedString("addWeight", comment: "") }
    static var addExpense: String { NSLocalizedString("addExpense", comment: "") }
    static var totalExpense: String { NSLocalizedString("totalExpense", comment: "") }
    static var expenseCategory: String { NSLocalizedString("expenseCategory", comment: "") }
    static var food: String { NSLocalizedString("food", comment: "") }
    static var toy: String { NSLocalizedString("toy", comment: "") }
    static var medical: String { NSLocalizedString("medical", comment: "") }
    static var cage: String { NSLocalizedString("cage", comment: "") }
    static var other: String { NSLocalizedString("other", comment: "") }
    
    // MARK: - 提醒
    static var addReminder: String { NSLocalizedString("addReminder", comment: "") }
    static var reminderTitle: String { NSLocalizedString("reminderTitle", comment: "") }
    static var reminderTime: String { NSLocalizedString("reminderTime", comment: "") }
    static var reminderRepeat: String { NSLocalizedString("reminderRepeat", comment: "") }
    static var daily: String { NSLocalizedString("daily", comment: "") }
    static var weekly: String { NSLocalizedString("weekly", comment: "") }
    static var monthly: String { NSLocalizedString("monthly", comment: "") }
    static var never: String { NSLocalizedString("never", comment: "") }
    
    // MARK: - 错误
    static var networkError: String { NSLocalizedString("networkError", comment: "") }
    static var unknownError: String { NSLocalizedString("unknownError", comment: "") }
    static var modelNotLoaded: String { NSLocalizedString("modelNotLoaded", comment: "") }
    static var recordingEmpty: String { NSLocalizedString("recordingEmpty", comment: "") }
    static var audioInitFailed: String { NSLocalizedString("audioInitFailed", comment: "") }
    static var cannotStartRecording: String { NSLocalizedString("cannotStartRecording", comment: "") }
    static var recordingFailed: String { NSLocalizedString("recordingFailed", comment: "") }
    
    // MARK: - 广场与UGC功能 (Forum & UGC)
    static var forumCommentsCount: String { NSLocalizedString("forumCommentsCount", comment: "") }
    static var forumNoComments: String { NSLocalizedString("forumNoComments", comment: "") }
    static var forumNoCommentsTitle: String { NSLocalizedString("forumNoCommentsTitle", comment: "") }
    static var forumNoCommentsHint: String { NSLocalizedString("forumNoCommentsHint", comment: "") }
    static var forumInputPlaceholder: String { NSLocalizedString("forumInputPlaceholder", comment: "") }
    static var forumDeleteCommentConfirmTitle: String { NSLocalizedString("forumDeleteCommentConfirmTitle", comment: "") }
    static var forumDeleteCommentConfirmMsg: String { NSLocalizedString("forumDeleteCommentConfirmMsg", comment: "") }
    static var forumCommentDeleted: String { NSLocalizedString("forumCommentDeleted", comment: "") }
    
    // MARK: - 拉黑 (Block)
    static var blockUser: String { NSLocalizedString("blockUser", comment: "") }
    static var unblockUser: String { NSLocalizedString("unblockUser", comment: "") }
    static var blockThisUser: String { NSLocalizedString("blockThisUser", comment: "") }
    static var confirmBlockTitle: String { NSLocalizedString("confirmBlockTitle", comment: "") }
    static var confirmBlockMessage: String { NSLocalizedString("confirmBlockMessage", comment: "") }
    static var confirmBlockPostMessage: String { NSLocalizedString("confirmBlockPostMessage", comment: "") }
    static var block: String { NSLocalizedString("block", comment: "") }
    
    // MARK: - 举报 (Report)
    static var reportPost: String { NSLocalizedString("reportPost", comment: "") }
    static var reportComment: String { NSLocalizedString("reportComment", comment: "") }
    static var reportTitle: String { NSLocalizedString("reportTitle", comment: "") }
    static var reportReasonPrompt: String { NSLocalizedString("reportReasonPrompt", comment: "") }
    static var reportAdditionalInfo: String { NSLocalizedString("reportAdditionalInfo", comment: "") }
    static var reportSubmit: String { NSLocalizedString("reportSubmit", comment: "") }
    static var reportSubmitting: String { NSLocalizedString("reportSubmitting", comment: "") }
    static var reportSuccessTitle: String { NSLocalizedString("reportSuccessTitle", comment: "") }
    static var reportSuccessMsg: String { NSLocalizedString("reportSuccessMsg", comment: "") }
    static var reportErrorTitle: String { NSLocalizedString("reportErrorTitle", comment: "") }
    static var reportSpam: String { NSLocalizedString("reportSpam", comment: "") }
    static var reportPorn: String { NSLocalizedString("reportPorn", comment: "") }
    static var reportViolence: String { NSLocalizedString("reportViolence", comment: "") }
    static var reportAbuse: String { NSLocalizedString("reportAbuse", comment: "") }
    static var reportFraud: String { NSLocalizedString("reportFraud", comment: "") }
    static var reportOther: String { NSLocalizedString("reportOther", comment: "") }
    static var loginRequiredTitle: String { NSLocalizedString("loginRequiredTitle", comment: "") }
    static var loginRequiredMsg: String { NSLocalizedString("loginRequiredMsg", comment: "") }
    
    // MARK: - 用户协议 (EULA & Login)
    static var eulaReadAndAgree: String { NSLocalizedString("eulaReadAndAgree", comment: "") }
    static var eulaUserAgreement: String { NSLocalizedString("eulaUserAgreement", comment: "") }
    static var eulaPrivacyPolicy: String { NSLocalizedString("eulaPrivacyPolicy", comment: "") }
    static var eulaPleaseAgree: String { NSLocalizedString("eulaPleaseAgree", comment: "") }
    static var hintTitle: String { NSLocalizedString("hintTitle", comment: "") }
}


// MARK: - Dynamic Language Switch Utility
private var bundleKey: UInt8 = 0

class LanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        
        let lprojName: String
        if language == "zh" {
            lprojName = "zh-Hans"
        } else {
            lprojName = language
        }
        
        let path = Bundle.main.path(forResource: lprojName, ofType: "lproj") ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
