"""
粤拼标注服务模块
"""
import pycantonese
import zhconv
from typing import Optional

try:
    import ToJyutping
except Exception:
    ToJyutping = None


def add_jyutping(cantonese_text: str) -> str:
    """
    自动添加粤拼（优先使用 ToJyutping 做多音字/词级处理；否则回退 PyCantonese 逐字标注）

    Args:
        cantonese_text: 要标注的粤语文本

    Returns:
        标注后的文本，格式为：字(拼音) 字(拼音)
    """
    try:
        if not cantonese_text:
            return ""

        # 优先：ToJyutping（更接近多数在线工具的选择）
        if ToJyutping is not None:
            try:
                parts: list[str] = []
                for char, jp in ToJyutping.get_jyutping_list(cantonese_text):
                    if char.isspace():
                        parts.append(char)
                        continue
                    if jp is None or str(jp).strip() in {"", "None"}:
                        parts.append(char)
                    else:
                        parts.append(f"{char}({str(jp).strip()})")
                return " ".join(parts)
            except Exception:
                # 失败则回退 PyCantonese
                pass

        # 将简体转换为繁体，以提高识别率
        traditional_text = zhconv.convert(cantonese_text, 'zh-hk')

        # 逐字标注拼音
        formatted_parts = []

        for i, char in enumerate(cantonese_text):
            # 跳过空白字符
            if char.isspace():
                formatted_parts.append(char)
                continue

            # 获取繁体字符（用于查询拼音）
            trad_char = traditional_text[i] if i < len(traditional_text) else char

            # 对单个字符进行粤拼标注
            try:
                # 使用 PyCantonese 的 characters_to_jyutping 函数处理单个字符
                result = pycantonese.characters_to_jyutping(trad_char) or []
                if result and len(result) > 0:
                    _, jyutping = result[0]
                    if jyutping is None or jyutping == "None" or jyutping == "":
                        jyutping = "?"
                else:
                    jyutping = "?"

            except:
                jyutping = "?"

            # 使用原始字符（保持简体/繁体）+ 拼音
            formatted_parts.append(f"{char}({jyutping})")

        return " ".join(formatted_parts)

    except Exception as e:
        raise Exception(f"粤拼标注失败: {str(e)}")
