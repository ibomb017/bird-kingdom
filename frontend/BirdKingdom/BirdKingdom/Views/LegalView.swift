import SwiftUI

// MARK: - 用户协议视图
struct UserAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("欢迎使用鸟鸟王国！")
                        .font(.headline)
                    
                    Text("请您仔细阅读以下条款。当您使用本应用时，即表示您已阅读、理解并同意接受本协议的所有条款。")
                        .foregroundColor(.secondary)
                    
                    agreementSection(
                        title: "一、服务说明",
                        content: """
                        1. 鸟鸟王国是一款专为鸟类爱好者设计的宠物鸟管理应用，提供鸟类档案管理、健康记录、饲养提醒、知识百科等功能。
                        
                        2. 我们致力于为用户提供优质的服务体验，但不对服务的及时性、安全性、准确性作出保证。
                        
                        3. 我们保留随时修改、中断或终止服务的权利，恕不另行通知。
                        """
                    )
                    
                    agreementSection(
                        title: "二、用户账号",
                        content: """
                        1. 您需要使用手机号码注册账号。每个手机号码只能注册一个账号。
                        
                        2. 您应妥善保管账号信息，对账号下的所有行为承担责任。
                        
                        3. 如发现账号被盗用或存在安全漏洞，请立即联系我们。
                        
                        4. 您的唯一ID可修改一次，修改后无法再次更改，请谨慎设置。
                        """
                    )
                    
                    agreementSection(
                        title: "三、用户行为规范",
                        content: """
                        1. 您应遵守中华人民共和国相关法律法规，不得利用本应用从事违法活动。
                        
                        2. 您不得发布虚假、有害、淫秽、暴力或侵犯他人权益的内容。
                        
                        3. 您不得干扰或破坏本应用的正常运行。
                        
                        4. 您不得未经授权访问、收集其他用户的个人信息。
                        
                        5. 违反上述规定的，我们有权采取警告、限制功能、封禁账号等措施。
                        """
                    )
                    
                    agreementSection(
                        title: "四、知识产权",
                        content: """
                        1. 本应用的所有内容，包括但不限于文字、图片、音频、视频、软件、程序、界面设计等，均受知识产权法保护。
                        
                        2. 未经我们书面许可，您不得复制、修改、传播本应用的任何内容。
                        
                        3. 您在本应用发布的原创内容，著作权归您所有，但您授予我们免费使用的权利。
                        """
                    )
                    
                    agreementSection(
                        title: "五、免责声明",
                        content: """
                        1. 本应用提供的鸟类饲养建议、健康知识仅供参考，不构成专业医疗建议。如您的鸟儿出现健康问题，请及时咨询专业兽医。
                        
                        2. 因不可抗力、网络故障、第三方服务中断等原因导致的服务中断或数据丢失，我们不承担责任。
                        
                        3. 用户之间因共享功能产生的纠纷，由用户自行协商解决。
                        """
                    )
                    
                    agreementSection(
                        title: "六、协议修改",
                        content: """
                        1. 我们保留随时修改本协议的权利。修改后的协议将在应用内公布。
                        
                        2. 如您继续使用本应用，即视为您接受修改后的协议。
                        
                        3. 如您不同意修改后的协议，请停止使用本应用。
                        """
                    )
                    
                    agreementSection(
                        title: "七、其他",
                        content: """
                        1. 本协议的解释、效力及纠纷解决，适用中华人民共和国法律。
                        
                        2. 如有任何争议，双方应友好协商解决；协商不成的，任何一方均可向本应用运营方所在地人民法院提起诉讼。
                        
                        3. 本协议自您注册账号或使用本应用之日起生效。
                        """
                    )
                    
                    Text("最后更新日期：2025年12月6日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .padding(20)
            }
            .navigationTitle("用户协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(forestGreen)
                }
            }
        }
    }
    
    private func agreementSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - 隐私政策视图
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    private let forestGreen = Color(red: 0.25, green: 0.42, blue: 0.35)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("我们深知个人信息对您的重要性，将尽全力保护您的个人信息安全。")
                        .foregroundColor(.secondary)
                    
                    policySection(
                        title: "一、我们收集的信息",
                        content: """
                        1. **账号信息**：手机号码、唯一ID、昵称、头像、个人简介。
                        
                        2. **鸟类信息**：您添加的鸟儿档案，包括昵称、品种、性别、出生日期、羽色、来源、健康记录等。
                        
                        3. **使用记录**：日志记录、体重数据、提醒设置、操作日志。
                        
                        4. **设备信息**：设备型号、操作系统版本、应用版本、网络状态。
                        
                        5. **位置信息**：仅在您授权后收集，用于提供本地化服务（如天气提醒）。
                        """
                    )
                    
                    policySection(
                        title: "二、我们如何使用信息",
                        content: """
                        1. **提供服务**：创建和管理您的账号，存储和同步您的鸟类数据。
                        
                        2. **功能实现**：实现共享功能，让您与他人共同管理鸟儿。
                        
                        3. **消息通知**：发送喂食提醒、健康提醒等通知。
                        
                        4. **改进服务**：分析使用数据，优化产品功能和用户体验。
                        
                        5. **安全保障**：识别异常行为，保护账号安全。
                        """
                    )
                    
                    policySection(
                        title: "三、信息共享",
                        content: """
                        1. **共享功能**：当您使用共享功能时，被邀请的用户可以查看或编辑您共享的鸟儿信息。
                        
                        2. **广场功能**：您在广场发布的内容将对其他用户可见。
                        
                        3. **第三方服务**：我们可能使用第三方服务（如云存储、推送服务），这些服务商将按照其隐私政策处理数据。
                        
                        4. **法律要求**：在法律要求或政府机关依法要求时，我们可能披露您的信息。
                        
                        5. 除上述情况外，未经您同意，我们不会向第三方共享您的个人信息。
                        """
                    )
                    
                    policySection(
                        title: "四、信息存储与保护",
                        content: """
                        1. **存储地点**：您的数据存储在中国境内的服务器。
                        
                        2. **存储期限**：在您使用服务期间，我们会持续存储您的数据。账号注销后，我们将在合理期限内删除您的个人信息。
                        
                        3. **安全措施**：我们采用加密传输、访问控制、安全审计等措施保护您的数据安全。
                        
                        4. **安全事件**：如发生数据泄露等安全事件，我们将及时通知您并采取补救措施。
                        """
                    )
                    
                    policySection(
                        title: "五、您的权利",
                        content: """
                        1. **查阅权**：您可以在应用内查看您的个人信息。
                        
                        2. **更正权**：您可以修改您的昵称、简介等信息。
                        
                        3. **删除权**：您可以删除您的鸟类档案和日志记录。
                        
                        4. **注销权**：您可以申请注销账号，我们将删除您的个人信息。
                        
                        5. **撤回同意**：您可以在设备设置中关闭通知、位置等权限。
                        """
                    )
                    
                    policySection(
                        title: "六、未成年人保护",
                        content: """
                        1. 本应用主要面向成年用户。如您是未成年人，请在监护人指导下使用本应用。
                        
                        2. 如监护人发现未成年人未经同意使用本应用，可联系我们删除相关信息。
                        """
                    )
                    
                    policySection(
                        title: "七、政策更新",
                        content: """
                        1. 我们可能适时修订本隐私政策。
                        
                        2. 重大变更将通过应用内通知或其他方式告知您。
                        
                        3. 如您继续使用本应用，即视为您接受更新后的隐私政策。
                        """
                    )
                    
                    policySection(
                        title: "八、联系我们",
                        content: """
                        如您对本隐私政策有任何疑问、意见或建议，可通过以下方式联系我们：
                        
                        邮箱：support@birdkingdom.app
                        
                        我们将在15个工作日内回复您的请求。
                        """
                    )
                    
                    Text("最后更新日期：2025年12月6日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .padding(20)
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(forestGreen)
                }
            }
        }
    }
    
    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

#Preview("用户协议") {
    UserAgreementView()
}

#Preview("隐私政策") {
    PrivacyPolicyView()
}
