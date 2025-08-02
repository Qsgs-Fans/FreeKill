-- SPDX-License-Identifier: GPL-3.0-or-later

local extension = Package:new("test_p_0")
extension.extensionName = "test"

local prefix = "./packages/"
if UsingNewCore then prefix = "./packages/freekill-core/" end

extension:loadSkillSkelsByPath(prefix .. "test/skills")

local test2 = General(extension, "mouxusheng", "wu", 4, 4, General.Female)
test2.shield = 3
test2.hidden = true
test2.endnote = "mouxusheng_endnote"
test2:addSkills {
  "test_rende",
  "cheat",
  "control",
  "damage_maker",
  "test_zhenggong",
  "change_hero",
  "test_zhijian",
}

Fk:loadTranslationTable{
  ["test_p_0"] = "测试",
  ["test"] = "测试",
  ["mouxusheng"] = "谋徐盛",
  ["~mouxusheng"] = "来世，愿再为我江东之臣……",
  ["mouxusheng_endnote"] = "测试用武将",
}

local shibing = General(extension, "blank_shibing", "qun", 5)
shibing.hidden = true
Fk:loadTranslationTable{
  ["blank_shibing"] = "男士兵",
}

local nvshibing = General(extension, "blank_nvshibing", "qun", 5, 5, General.Female)
Fk:loadTranslationTable{
  ["blank_nvshibing"] = "女士兵",
}
nvshibing.hidden = true

Fk:loadTranslationTable({
  ["test_kansha"] = "Khán Sát",
  [":test_kansha"] = "Tỏa định kỹ, bạn có thể thấy 【Sát】 trên tay của người khác",
  ["blank_shibing"] = "Nam Binh Sĩ",
  ["blank_nvshibing"] = "Nữ Binh Sĩ",
  ["test_p_0"] = "Thử nghiệm",
  ["test"] = "Test",
  ["test_filter"] = "Phá Quân",
  [":test_filter"] = "Những lá có điểm lớn hơn 11 của bạn được xem như [Vô Trung Sinh Hữu].",
  ["mouxusheng"] = "Từ Thịnh - Mưu",
  ["cheat"] = "Gian Lận",
  [":cheat"] = "Giai đoạn ra bài, bạn có thể thu lấy lá bạn muốn.",
  ["#cheat"] = "Cheat: Bạn có thể thu lấy 1 lá bạn muốn",
  ["$cheat"] = "Uống nào!",
  ["control"] = "Kiểm Soát",
  [":control"] = "Giai đoạn ra bài, bạn có thể thay đổi trạng thái \"Kiểm Soát\" những người khác. Bạn được điều khiển người có trạng thái \"Kiểm Soát\"",
  ["$control"] = "Chiến tướng lâm trận, chém cửa phá thành!",
  ["test_vs"] = "Thị Vy",
  [":test_vs"] = "Bạn có thể chuyển hóa sử dụng bài → công cụ.",
  ["#test_vs"] = "Thị Vy: Bạn có thể học cách sử dụng công cụ",
  ["damage_maker"] = "Chế Thương",
  [":damage_maker"] = "Giai đoạn ra bài, bạn có thể gây 1 sát thương.",
  ["#damage_maker"] = "Chế Thương: Chọn 1 con chuột bạch, có thể chọn 1 người khác làm nguồn sát thương（mặc định là Từ Thịnh - Mưu）",
  ["#revive-ask"] = "Hồi sinh 1 người!",
  ["$damage_maker"] = "Chỉ vài trăm quân Ngụy, xem ta 1 lần diệt hết!",
  ["test_zhenggong"] = "Tốc Trắc",
  [":test_zhenggong"] = "Tỏa định kỹ, khi bắt đầu lượt đầu tiên, bạn thực hiện thêm 1 lượt.",
  ["$test_zhenggong"] = "Kế nghi binh này, đã làm quân định mất hết can đảm, chúng nào dám tiến gần!",
  ["change_hero"] = "Biến Đổi",
  [":change_hero"] = "Giai đoạn ra bài, bạn có thể đổi tướng của 1 người.",
  ["$change_hero"] = "Quân địch ngoài mạnh trong yếu, có thể xây thành giả để lui địch!",
  ["~mouxusheng"] = "Kiếp sau, nguyện lại là thần tử Giang Đông... ...",
  ["heal_hp"] = "Hồi máu",
  ["lose_max_hp"] = "Giảm giới hạn máu",
  ["heal_max_hp"] = "Tăng giới hạn máu",
  ["revive"] = "Hồi sinh",
}, "vi_VN")

return extension
