/*
 * 联系人数据模型与表格列定义。`Contact` 是不可变值；编辑通过用新值替换整个联系人完成，
 * 与框架“单一数据源、整体替换”的状态更新方式一致。
 */
package cui_contacts

import cui.TableColumn

struct Contact {
    let id: Int64
    let name: String
    let company: String
    let role: String
    let email: String

    public init(id: Int64, name: String, company: String, role: String, email: String) {
        this.id = id
        this.name = name
        this.company = company
        this.role = role
        this.email = email
    }
}

func contactColumns(): Array<TableColumn> {
    [
        TableColumn("姓名", 130.0),
        TableColumn("公司", 160.0),
        TableColumn("职务", 130.0),
        TableColumn("邮箱", 230.0)
    ]
}

func seedContacts(): Array<Contact> {
    [
        Contact(1, "林晚", "未来数据", "产品经理", "lin.wan@future.com"),
        Contact(2, "陈屿", "星河科技", "前端工程师", "chen.yu@galaxy.io"),
        Contact(3, "苏澈", "未来数据", "设计师", "su.che@future.com"),
        Contact(4, "周牧", "云枢网络", "后端工程师", "zhou.mu@yunshu.net"),
        Contact(5, "何知遇", "星河科技", "市场经理", "he.zy@galaxy.io"),
        Contact(6, "顾清", "青柠工作室", "创始人", "gu.qing@limes.studio"),
        Contact(7, "叶蓁", "云枢网络", "运营", "ye.zhen@yunshu.net"),
        Contact(8, "沈昭", "未来数据", "数据分析师", "shen.zhao@future.com"),
        Contact(9, "白露", "青柠工作室", "设计师", "bai.lu@limes.studio"),
        Contact(10, "泊烟渚", "星河科技", "销售经理", "meng.wz@galaxy.io"),
        Contact(11, "江既明", "云枢网络", "产品经理", "jiang.jm@yunshu.net"),
        Contact(12, "温言", "青柠工作室", "内容运营", "wen.yan@limes.studio")
    ]
}

/** 公司建议：搜索组合框在此基础上过滤，也允许键入未列出的公司。 */
func companySuggestions(): Array<String> {
    ["未来数据", "星河科技", "云枢网络", "青柠工作室"]
}
