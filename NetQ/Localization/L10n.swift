import Foundation

enum L10n {
    static let table: [String: (zh: String, en: String)] = [
        "tab.map": ("地图", "Map"), "tab.detect": ("检测", "Detect"), "tab.settings": ("设置", "Settings"),
        "pending.desc": ("该模块将在后续批次交付。", "This module ships in a later batch."),
        "set.device": ("设备信息", "Device"), "set.appearance": ("外观", "Appearance"),
        "set.display": ("界面显示", "Display"), "set.language": ("语言", "Language"),
        "set.privacy": ("隐私说明", "Privacy"), "set.licenses": ("开源许可", "Open Source Licenses"),
        "set.about": ("关于 NetQ", "About NetQ"),
        "dev.name": ("设备名称", "Device Name"), "dev.model": ("设备型号", "Model"),
        "dev.os": ("系统名称", "System"), "dev.osv": ("系统版本", "System Version"),
        "dev.ver": ("App 版本", "App Version"), "dev.build": ("Build 版本", "Build"),
        "ap.mode": ("外观模式", "Mode"), "ap.system": ("跟随系统", "System"),
        "ap.light": ("浅色", "Light"), "ap.dark": ("深色", "Dark"), "ap.accent": ("强调色", "Accent Color"),
        "c.blue": ("蓝色", "Blue"), "c.purple": ("紫色", "Purple"), "c.green": ("绿色", "Green"),
        "c.orange": ("橙色", "Orange"), "c.red": ("红色", "Red"), "c.pink": ("粉色", "Pink"),
        "c.custom": ("自定义", "Custom"), "c.pick": ("自定义颜色", "Custom Color"),
        "ts.title": ("字体大小", "Text Size"), "ts.small": ("小", "Small"), "ts.standard": ("标准", "Standard"),
        "ts.large": ("大", "Large"), "ts.xLarge": ("超大", "Extra Large"),
        "dn.title": ("界面密度", "Density"), "dn.compact": ("紧凑", "Compact"),
        "dn.standard": ("标准", "Standard"), "dn.relaxed": ("宽松", "Relaxed"),
        "lang.zh": ("简体中文", "简体中文"), "lang.en": ("English", "English"),
        "priv.body": (
            "NetQ 默认不收集无关个人信息，没有账号体系，也没有自己的服务器。\n\n• IP 获取：App 直接向公共 IP 查询服务发起请求，这些服务会看到你的公网 IP。\n• 定位权限：仅用于在地图上显示设备位置，与 IP 定位分开展示，数据不离开设备。\n• 检测数据：测速与延迟检测只与测速服务器和你添加的节点通信。\n• 存储：设置、节点列表与检测报告仅保存在本机。\n• 报告不会自动上传，只有你主动分享时才会离开设备。\n• 删除：卸载 App 即清除全部本地数据。",
            "NetQ collects no unrelated personal data. There are no accounts and no NetQ servers.\n\n• IP lookup: the app calls public IP services directly; those services see your public IP.\n• Location: used only to show the device position on the map, kept separate from IP-based location, and never leaves the device.\n• Test data: speed and latency tests talk only to test servers and nodes you add.\n• Storage: settings, nodes and reports stay on this device.\n• Reports are never uploaded automatically; they leave the device only when you share them.\n• Deletion: uninstalling the app removes all local data."),
        "lic.none": ("当前未内置第三方代码库，仅调用下列在线服务与 Apple 系统框架。使用前请自行核对各服务的最新条款与额度。",
                     "No third-party code libraries are bundled; only the online services and Apple frameworks below are used. Please check each provider's current terms and limits."),
        "about.dev": ("开发者", "Developer"), "about.links": ("链接", "Links"),
    ]

    static func text(_ key: String, _ lang: AppLanguage) -> String {
        guard let e = table[key] ?? mapTable[key] ?? speedTable[key] ?? detectTable[key] ?? nodeTable[key] else { return key }
        return lang == .zh ? e.zh : e.en
    }
}
