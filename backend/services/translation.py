"""
翻译服务模块
"""
import requests
import json


def fetch_available_models(base_url: str, api_key: str) -> list[str]:
    """从OpenAI兼容的API获取可用模型列表"""
    try:
        # 规范化base_url：确保以/v1结尾
        base_url = base_url.rstrip('/')
        if not base_url.endswith('/v1'):
            base_url = base_url + '/v1'

        # 构建models端点URL
        models_url = base_url.rstrip('/') + '/models'

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }

        response = requests.get(models_url, headers=headers, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if "data" in data and isinstance(data["data"], list):
                models = [model["id"] for model in data["data"] if "id" in model]
                return sorted(models)
            else:
                return []
        else:
            raise Exception(f"HTTP {response.status_code}: {response.text[:200]}")
    except Exception as e:
        raise Exception(f"获取模型列表失败: {str(e)}")


def translate_to_cantonese(
    text: str,
    api_key: str,
    model_name: str,
    base_url: str,
    slang_mode: bool = False
) -> dict:
    """
    使用OpenAI兼容的API翻译成粤语

    Args:
        text: 要翻译的普通话文本
        api_key: API密钥
        model_name: 模型名称
        base_url: API基础URL
        slang_mode: 是否启用俚语模式

    Returns:
        包含翻译结果的字典
    """
    # 规范化base_url：确保以/v1结尾
    base_url = base_url.rstrip('/')
    if not base_url.endswith('/v1'):
        base_url = base_url + '/v1'

    # 构建chat/completions端点URL
    url = base_url.rstrip('/') + '/chat/completions'
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    if slang_mode:
        # 俚语模式：返回完整的JSON结构
        system_prompt = """You are a native Cantonese linguistics expert (Old Guang). Your task is to translate Mandarin to Cantonese and provide detailed information."""
        user_prompt = f"""
Role: You are a native Cantonese linguistics expert (Old Guang).

Task: Translate Mandarin to Cantonese.

Input: "{text}"

Requirements:
1. "cantonese": Standard colloquial Cantonese (e.g., 100 yuan -> 一百蚊).
2. "slang": VERY local, street slang if available (e.g., 100 yuan -> 一旧水, Police -> 差佬/阿Sir, Boss -> 老細, Work/Earn money -> 搵食, Very good -> 好犀利/好巴闭). If no specific slang exists, strictly return null.
3. "note": Explain the difference and cultural context in Simplified Chinese (普通话). Use clear and concise language. (optional, can be empty).

Do not include jyutping fields; the server will annotate Cantonese text automatically.

Common slang examples:
- Money: 10元->一草嘢, 100元->一旧水, 1000元->一撇水, 10000元->一皮嘢/一鸡嘢
- People: 警察->差佬/阿Sir, 老板->老細
- Actions: 工作->搵食, 吃饭->食嘢

Output JSON (NO markdown code blocks):
{{
    "cantonese": "...",
    "slang": "..." or null,
    "note": "..."
}}
"""
    else:
        # 标准模式：只返回粤语翻译
        system_prompt = "You are a Cantonese translation expert. Translate Mandarin to colloquial Cantonese."
        user_prompt = f"""请将以下普通话翻译成地道的粤语（口语，非书面语）。
只需要输出粤语翻译结果，不要任何解释、注释或额外内容。
使用繁体中文。

普通话：{text}

粤语："""

    data = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 1024
    }

    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)

        # 检查HTTP状态码
        if response.status_code != 200:
            error_detail = ""
            try:
                error_data = response.json()
                # 尝试多种方式提取错误信息
                if "message" in error_data:
                    error_detail = error_data["message"]
                elif "error" in error_data:
                    if isinstance(error_data["error"], dict):
                        error_detail = error_data["error"].get("message", str(error_data["error"]))
                    else:
                        error_detail = str(error_data["error"])
                else:
                    error_detail = json.dumps(error_data, ensure_ascii=False)
            except:
                error_detail = response.text[:500]

            raise Exception(f"HTTP {response.status_code}: {error_detail}")

        result_data = response.json()

        # 检查响应格式
        if "choices" not in result_data or len(result_data["choices"]) == 0:
            raise Exception("API响应格式错误：未找到choices字段")

        if "message" not in result_data["choices"][0]:
            raise Exception("API响应格式错误：未找到message字段")

        result_text = result_data["choices"][0]["message"]["content"].strip()

        if slang_mode:
            # 解析JSON
            try:
                clean_text = result_text.replace("```json", "").replace("```", "").strip()
                result = json.loads(clean_text)
                return result
            except Exception as json_error:
                # JSON解析失败，返回原始回复
                return {
                    "cantonese": result_text,
                    "slang": None,
                    "jyutping": "",
                    "slang_jyutping": None,
                    "note": ""
                }
        else:
            # 标准模式，返回字符串
            return {
                "cantonese": result_text,
                "slang": None,
                "jyutping": "",
                "slang_jyutping": None,
                "note": ""
            }

    except requests.exceptions.RequestException as e:
        raise Exception(f"网络请求错误: {str(e)}")
    except json.JSONDecodeError as e:
        raise Exception(f"JSON解析错误: {str(e)}")
    except Exception as e:
        raise Exception(f"API错误: {str(e)}")


def explain_cantonese(
    text: str,
    api_key: str,
    model_name: str,
    base_url: str
) -> str:
    """
    使用AI解释粤语内容

    Args:
        text: 要解释的粤语内容
        api_key: API密钥
        model_name: 模型名称
        base_url: API基础URL

    Returns:
        AI生成的解释文本
    """
    # 规范化base_url
    base_url = base_url.rstrip('/')
    if not base_url.endswith('/v1'):
        base_url = base_url + '/v1'

    url = base_url.rstrip('/') + '/chat/completions'
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    system_prompt = "You are a Cantonese language expert. Explain Cantonese words and phrases in Mandarin Chinese with detailed cultural context."
    user_prompt = f"""请用普通话详细解释以下粤语内容：

粤语：{text}

请包括：
1. **字面意思**：逐字或逐词的字面含义
2. **实际含义**：在日常对话中的真实意思
3. **使用场景**：什么情况下使用这个表达
4. **文化背景**：相关的文化或历史背景（如有）
5. **普通话对应**：对应的普通话说法
6. **例句**：用粤语举1-2个实际使用例子，并附上普通话翻译

请用清晰、通俗易懂的普通话解释。"""

    data = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 2048
    }

    try:
        response = requests.post(url, headers=headers, json=data, timeout=30)

        if response.status_code != 200:
            error_detail = ""
            try:
                error_data = response.json()
                if "message" in error_data:
                    error_detail = error_data["message"]
                elif "error" in error_data:
                    if isinstance(error_data["error"], dict):
                        error_detail = error_data["error"].get("message", str(error_data["error"]))
                    else:
                        error_detail = str(error_data["error"])
                else:
                    error_detail = json.dumps(error_data, ensure_ascii=False)
            except:
                error_detail = response.text[:500]

            raise Exception(f"HTTP {response.status_code}: {error_detail}")

        result_data = response.json()
        explanation = result_data["choices"][0]["message"]["content"].strip()
        return explanation

    except Exception as e:
        raise Exception(f"解释生成失败: {str(e)}")
