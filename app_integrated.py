import streamlit as st
import pycantonese
import edge_tts
import asyncio
import tempfile
import os
import atexit
import glob
import requests
import json
import zhconv  # 简繁体转换

st.set_page_config(page_title="粤语学习助手", page_icon="🗣️", layout="wide")

# 临时文件管理
TEMP_AUDIO_DIR = tempfile.gettempdir()
AUDIO_FILES = []

def cleanup_audio_files():
    """清理所有生成的临时音频文件"""
    for audio_file in AUDIO_FILES:
        try:
            if os.path.exists(audio_file):
                os.remove(audio_file)
        except:
            pass

# 程序退出时清理
atexit.register(cleanup_audio_files)

# 获取可用模型列表
def fetch_available_models(base_url, api_key):
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

# 自定义样式
st.markdown("""
    <style>
    .jyutping {
        font-size: 18px;
        color: #666;
        font-family: 'Courier New', monospace;
        background-color: #f0f2f6;
        padding: 10px;
        border-radius: 5px;
        margin: 10px 0;
        display: flex;
        align-items: center;
        justify-content: space-between;
        width: 100%;
    }
    .jyutping-content {
        flex: 1;
    }
    .jyutping-audio {
        margin-left: 15px;
        display: flex;
        align-items: center;
        flex-shrink: 0;
    }
    .audio-button {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border: none;
        border-radius: 50%;
        width: 40px;
        height: 40px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        transition: all 0.3s ease;
    }
    .audio-button:hover {
        transform: scale(1.1);
        box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
    }
    .audio-button:active {
        transform: scale(0.95);
    }
    .cantonese-text {
        font-size: 24px;
        font-weight: bold;
        color: #FF4B4B;
        margin: 10px 0;
    }
    /* 隐藏默认audio控件，使用自定义样式 */
    .custom-audio {
        display: none;
    }
    </style>
    """, unsafe_allow_html=True)

st.title("🗣️ 粤语学习助手")
st.markdown("**提供普通话转粤语、粤语拼音标注、粤语解释三大功能**")

# 侧边栏设置
with st.sidebar:
    st.header("⚙️ 设置")

    # API配置
    st.subheader("🔌 API配置")
    
    # Base URL输入
    base_url = st.text_input(
        "Base URL",
        value=os.getenv("API_BASE_URL", "https://api.siliconflow.cn/v1"),
        help="OpenAI兼容的API Base URL，例如: https://api.siliconflow.cn/v1"
    )
    
    # API Key输入
    api_key = st.text_input("API Key", type="password", value=os.getenv("API_KEY", ""))
    
    # 获取可用模型列表
    st.subheader("🤖 模型选择")
    
    # 初始化session state
    if "available_models" not in st.session_state:
        st.session_state.available_models = []
    if "model_cache_key" not in st.session_state:
        st.session_state.model_cache_key = ""
    
    # 检查是否需要刷新模型列表
    current_cache_key = f"{base_url}_{api_key}"
    if current_cache_key != st.session_state.model_cache_key or not st.session_state.available_models:
        if base_url and api_key:
            with st.spinner("正在获取可用模型列表..."):
                try:
                    models = fetch_available_models(base_url, api_key)
                    if models:
                        st.session_state.available_models = models
                        st.session_state.model_cache_key = current_cache_key
                        st.success(f"✅ 成功获取 {len(models)} 个可用模型")
                    else:
                        st.warning("⚠️ 未能获取到可用模型，请检查Base URL和API Key")
                except Exception as e:
                    st.error(f"❌ 获取模型列表失败: {str(e)}")
                    st.session_state.available_models = []
        else:
            st.session_state.available_models = []
    
    # 显示模型选择
    if st.session_state.available_models:
        model_options = {model: model for model in st.session_state.available_models}
        selected_model = st.selectbox(
            "选择AI模型",
            options=list(model_options.keys()),
            index=0 if len(model_options) > 0 else None
        )
    else:
        # 如果没有可用模型，显示手动输入
        selected_model = st.text_input(
            "手动输入模型名称",
            value="",
            placeholder="例如: deepseek-ai/DeepSeek-V3",
            help="如果无法自动获取模型列表，可以手动输入模型名称"
        )
        if not selected_model:
            st.warning("⚠️ 请输入模型名称或配置Base URL和API Key以自动获取")
    
    # 刷新模型列表按钮
    if base_url and api_key:
        if st.button("🔄 刷新模型列表", use_container_width=True):
            st.session_state.model_cache_key = ""
            st.rerun()
    
    st.caption(f"当前模型: {selected_model if selected_model else '未选择'}")

    st.divider()

    st.subheader("🎤 语音设置")
    voice_options = {
        "晓曼 (女声)": "zh-HK-HiuMaanNeural",
        "晓佳 (女声)": "zh-HK-HiuGaaiNeural",
        "云龙 (男声)": "zh-HK-WanLungNeural"
    }
    selected_voice_name = st.selectbox(
        "选择配音员",
        options=list(voice_options.keys()),
        index=0
    )
    selected_voice = voice_options[selected_voice_name]

    st.divider()

    st.subheader("🔥 俚语模式")
    slang_mode = st.checkbox(
        "启用地道俚语/黑话",
        value=True,
        help="开启后，AI会额外提供更地道的市井俚语表达（如：一旧水、老细、搵食等）"
    )
    if slang_mode:
        st.info("💡 俚语模式已启用：会显示地道黑话版本")
    else:
        st.info("📖 标准模式：仅显示标准口语")

    st.divider()

    st.subheader("💬 对话管理")
    
    # 初始化对话历史
    if "conversations" not in st.session_state:
        st.session_state.conversations = {}
        st.session_state.conversations["default"] = []
    
    if "current_conversation_id" not in st.session_state:
        st.session_state.current_conversation_id = "default"
    
    # 创建新对话
    if st.button("➕ 新建对话", use_container_width=True):
        from datetime import datetime
        new_id = f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        st.session_state.conversations[new_id] = []
        st.session_state.current_conversation_id = new_id
        st.session_state.messages = []
        st.rerun()
    
    # 显示对话列表
    st.markdown("**对话列表:**")
    conversation_list = list(st.session_state.conversations.keys())
    
    # 显示当前对话和对话列表
    for conv_id in conversation_list:
        conv_name = conv_id.replace("chat_", "对话 ").replace("_", " ").replace("default", "默认对话")
        conv_messages = st.session_state.conversations[conv_id]
        message_count = len([m for m in conv_messages if m.get("role") == "user"])
        
        # 创建列用于显示对话名称和删除按钮
        col1, col2 = st.columns([4, 1])
        with col1:
            is_current = conv_id == st.session_state.current_conversation_id
            if is_current:
                st.markdown(f"**📌 {conv_name}** ({message_count}条)")
            else:
                if st.button(f"💬 {conv_name} ({message_count}条)", key=f"switch_{conv_id}", use_container_width=True):
                    # 保存当前对话
                    st.session_state.conversations[st.session_state.current_conversation_id] = st.session_state.messages.copy()
                    # 切换到新对话
                    st.session_state.current_conversation_id = conv_id
                    st.session_state.messages = st.session_state.conversations[conv_id].copy()
                    st.rerun()
        with col2:
            if conv_id != "default" and st.button("🗑️", key=f"delete_{conv_id}", help="删除对话"):
                # 如果删除的是当前对话，切换到默认对话
                if conv_id == st.session_state.current_conversation_id:
                    st.session_state.current_conversation_id = "default"
                    st.session_state.messages = st.session_state.conversations["default"].copy()
                del st.session_state.conversations[conv_id]
                st.rerun()
    
    st.divider()
    st.caption(f"📁 临时语音文件: {len(AUDIO_FILES)} 个")
    st.caption(f"📂 存储位置: {TEMP_AUDIO_DIR}")
    if st.button("🧹 立即清理音频文件"):
        cleanup_audio_files()
        AUDIO_FILES.clear()
        st.success("✅ 已清理所有临时音频文件")

# 粤语翻译函数
def translate_to_cantonese(text, api_key, model_name, base_url, slang_mode=False):
    """使用 OpenAI 兼容 API 翻译；粤拼由本地 PyCantonese 在展示阶段生成。"""
    try:
        return _translate_with_openai_api(text, api_key, model_name, base_url, slang_mode)
    except Exception as e:
        error_msg = str(e)
        if slang_mode:
            return {
                "cantonese": f"❌ API错误",
                "slang": None,
                "jyutping": "",
                "slang_jyutping": None,
                "note": error_msg
            }
        else:
            return f"❌ 翻译失败: {error_msg}"

def _translate_with_openai_api(text, api_key, model_name, base_url, slang_mode):
    """使用OpenAI兼容的API翻译"""
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

Do not include jyutping in JSON; the app will annotate with PyCantonese after translation.

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
                error_detail = response.text[:500]  # 限制长度
            
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
                # JSON解析失败，原样显示AI的实际回复内容，不生成粤拼和语音
                return {
                    "cantonese": result_text,  # 显示AI的原始回复
                    "slang": None,
                    "jyutping": "",  # 空字符串，不生成粤拼
                    "slang_jyutping": None,
                    "note": ""
                }
        else:
            return result_text
            
    except requests.exceptions.RequestException as e:
        raise Exception(f"网络请求错误: {str(e)}")
    except json.JSONDecodeError as e:
        raise Exception(f"JSON解析错误: {str(e)}")
    except Exception as e:
        raise Exception(f"API错误: {str(e)}")

def is_error_message(text):
    """检测文本是否为错误消息"""
    error_keywords = ["失败", "错误", "Error", "error", "❌", "出错", "Exception", "API"]
    return any(keyword in text for keyword in error_keywords)

# 粤拼标注函数
def add_jyutping(cantonese_text):
    """使用PyCantonese自动添加粤拼（支持简体和繁体，逐字标注）"""
    try:
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
                result = pycantonese.characters_to_jyutping(trad_char)

                if result and len(result) > 0:
                    # 获取第一个结果的拼音
                    _, jyutping = result[0]

                    # 处理 None 的情况
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
        return f"❌ 粤拼标注失败: {str(e)}"

# 语音生成函数
async def generate_audio_async(text, voice):
    """使用edge-tts生成语音"""
    communicate = edge_tts.Communicate(text, voice)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as fp:
        await communicate.save(fp.name)
        # 添加到跟踪列表
        AUDIO_FILES.append(fp.name)
        return fp.name

def generate_audio(text, voice):
    """同步包装"""
    try:
        # 检查是否为错误消息
        if is_error_message(text):
            return None
        return asyncio.run(generate_audio_async(text, voice))
    except Exception as e:
        # 不在函数内部显示错误，避免在spinner内部调用st.error导致页面刷新
        # 错误会被调用者处理
        return None

# 创建标签页
tab1, tab2 = st.tabs(["🗣️ 普通话转粤语", "💬 粤语解释"])

# ============ 标签页1: 普通话转粤语 ============
with tab1:
    # 初始化会话状态
    if "messages" not in st.session_state:
        st.session_state.messages = []

    # 确保当前对话的消息与session_state.messages同步
    if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
        current_id = st.session_state.current_conversation_id
        if current_id in st.session_state.conversations:
            # 如果当前对话有消息，加载它们；否则保存当前消息到对话
            if st.session_state.conversations[current_id]:
                st.session_state.messages = st.session_state.conversations[current_id].copy()
            else:
                st.session_state.conversations[current_id] = st.session_state.messages.copy()

    # 显示历史消息
    for idx, message in enumerate(st.session_state.messages):
        with st.chat_message(message["role"]):
            if message["role"] == "user":
                st.markdown(message["content"])
            else:
                # 根据状态显示不同内容
                status = message.get("status", "completed")

                if status == "translating":
                    # 显示"翻译中..."
                    st.markdown("🤔 **翻译中...**")
                elif status == "generating_audio":
                    # 只显示"生成标准语音..."，不显示翻译结果
                    st.markdown("🔊 **生成标准语音...**")
                elif status == "generating_slang_audio":
                    # 只显示"生成俚语版语音..."，不显示之前的内容
                    st.markdown("🔊 **生成俚语版语音...**")
                elif status == "completed" or status == "":
                    # 显示完整内容
                    # 显示标准版
                    if message.get("has_slang"):
                        st.markdown(f'<div class="cantonese-text">📖 标准口语：{message["cantonese"]}</div>', unsafe_allow_html=True)
                    else:
                        st.markdown(f'<div class="cantonese-text">{message["cantonese"]}</div>', unsafe_allow_html=True)

                    # 显示标准版粤拼 + 语音
                    if message.get("jyutping") and (message.get("audio_standard") or message.get("audio")):
                        audio_standard = message.get("audio_standard") or message.get("audio")
                        col1, col2 = st.columns([5, 1])
                        with col1:
                            st.markdown(f'<div class="jyutping" style="background-color: #f0f2f6;"><span class="jyutping-content">{message.get("jyutping", "")}</span></div>', unsafe_allow_html=True)
                        with col2:
                            if audio_standard and os.path.exists(audio_standard):
                                st.audio(audio_standard, format="audio/mp3", autoplay=False)
                            else:
                                st.write("")  # 占位

                    # 显示俚语版（如果有）
                    if message.get("has_slang") and message.get("cantonese_slang"):
                        st.markdown(f'<div class="cantonese-text" style="color: #FF6B35;">🔥 地道黑话：{message["cantonese_slang"]}</div>', unsafe_allow_html=True)

                        # 显示俚语版粤拼 + 语音
                        if message.get("jyutping_slang") and message.get("audio_slang"):
                            col1, col2 = st.columns([5, 1])
                            with col1:
                                st.markdown(f'<div class="jyutping" style="background-color: #fff3e0;"><span class="jyutping-content">{message.get("jyutping_slang", "")}</span></div>', unsafe_allow_html=True)
                            with col2:
                                audio_slang = message.get("audio_slang")
                                if audio_slang and os.path.exists(audio_slang):
                                    st.audio(audio_slang, format="audio/mp3", autoplay=False)
                                else:
                                    st.write("")  # 占位

                    # 显示note（如果有）- 立即显示，不等到下一条消息
                    if message.get("note"):
                        st.info(f"💡 **老广笔记：** {message['note']}")

                    # 重新生成按钮
                    if st.button("🔄 重新生成", key=f"regen_{idx}"):
                        # 找到对应的用户输入
                        user_msg_idx = idx - 1
                        if user_msg_idx >= 0 and st.session_state.messages[user_msg_idx]["role"] == "user":
                            user_input = st.session_state.messages[user_msg_idx]["content"]
                            # 删除旧消息（删除AI回复）
                            del st.session_state.messages[idx]
                            # 同步更新到对话历史，避免rerun后重新加载旧消息
                            if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                                current_id = st.session_state.current_conversation_id
                                if current_id in st.session_state.conversations:
                                    st.session_state.conversations[current_id] = st.session_state.messages.copy()
                            # 保存要插入的位置（用户消息后，即user_msg_idx + 1）
                            st.session_state.regenerate_input = user_input
                            st.session_state.regenerate_insert_idx = user_msg_idx + 1
                            st.rerun()

    # 处理重新生成请求
    if "regenerate_input" in st.session_state:
        regen_input = st.session_state.regenerate_input
        insert_idx = st.session_state.get("regenerate_insert_idx", len(st.session_state.messages))

        # 清除标记
        del st.session_state.regenerate_input
        if "regenerate_insert_idx" in st.session_state:
            del st.session_state.regenerate_insert_idx

        # 重新生成（不显示，只更新session state）
        if not selected_model:
            st.error("❌ 请先选择或输入模型名称")
        else:
            with st.spinner("🤔 重新翻译中..."):
                result = translate_to_cantonese(regen_input, api_key, selected_model, base_url, slang_mode)

            # 处理结果并插入新消息到正确位置（替换原来的回复）
            if slang_mode and isinstance(result, dict):
                cantonese_standard = result.get("cantonese", "")
                cantonese_slang = result.get("slang")
                note = result.get("note", "")
                jyutping = ""
                jyutping_slang = ""
                if cantonese_standard and not is_error_message(str(cantonese_standard)):
                    jyutping = add_jyutping(cantonese_standard)
                if cantonese_slang and str(cantonese_slang).strip() and not is_error_message(str(cantonese_slang)):
                    jyutping_slang = add_jyutping(str(cantonese_slang))

                # 生成音频
                if not is_error_message(str(cantonese_standard)):
                    audio_standard = generate_audio(cantonese_standard, selected_voice)
                    if cantonese_slang and cantonese_slang != cantonese_standard:
                        audio_slang = generate_audio(cantonese_slang, selected_voice)
                        has_slang = True
                    else:
                        audio_slang = None
                        has_slang = False
                else:
                    audio_standard = None
                    audio_slang = None
                    has_slang = False

                # 插入新消息到正确位置（替换原来的回复）
                new_message = {
                    "role": "assistant",
                    "status": "completed",
                    "cantonese": cantonese_standard,
                    "cantonese_slang": cantonese_slang if has_slang else "",
                    "jyutping": jyutping,
                    "jyutping_slang": jyutping_slang if has_slang else "",
                    "audio_standard": audio_standard,
                    "audio_slang": audio_slang,
                    "has_slang": has_slang,
                    "note": note
                }
                st.session_state.messages.insert(insert_idx, new_message)
            else:
                cantonese = result if isinstance(result, str) else result.get("cantonese", "")
                if not is_error_message(str(cantonese)):
                    jyutping = add_jyutping(cantonese)
                    audio_path = generate_audio(cantonese, selected_voice)
                else:
                    jyutping = ""
                    audio_path = None

                new_message = {
                    "role": "assistant",
                    "status": "completed",
                    "cantonese": cantonese,
                    "cantonese_slang": "",
                    "jyutping": jyutping,
                    "jyutping_slang": "",
                    "audio_standard": audio_path,
                    "audio_slang": None,
                    "has_slang": False,
                    "note": ""
                }
                st.session_state.messages.insert(insert_idx, new_message)

            # 自动保存到当前对话
            if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                current_id = st.session_state.current_conversation_id
                if current_id in st.session_state.conversations:
                    st.session_state.conversations[current_id] = st.session_state.messages.copy()

            st.rerun()

    # 聊天输入
    if prompt := st.chat_input("输入普通话..."):
        if not api_key:
            st.error("❌ 请先在侧边栏输入 API Key")
        else:
            # 先保存用户输入到 session_state
            st.session_state.messages.append({"role": "user", "content": prompt})

            # 添加一个AI消息占位符，显示"翻译中..."
            st.session_state.messages.append({
                "role": "assistant",
                "status": "translating",
                "cantonese": "",
                "cantonese_slang": "",
                "jyutping": "",
                "jyutping_slang": "",
                "has_slang": False,
                "note": "",
                "audio_standard": None,
                "audio_slang": None
            })

            # 保存到当前对话
            if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                current_id = st.session_state.current_conversation_id
                if current_id in st.session_state.conversations:
                    st.session_state.conversations[current_id] = st.session_state.messages.copy()

            # 立即显示用户消息和"翻译中"状态
            st.rerun()

    # 处理翻译状态
    if st.session_state.messages and api_key:
        last_message = st.session_state.messages[-1]
        if last_message.get("role") == "assistant" and last_message.get("status") == "translating":
            # 开始翻译
            prompt = st.session_state.messages[-2]["content"] if len(st.session_state.messages) >= 2 else ""

            if prompt:
                if not selected_model:
                    st.error("❌ 请先选择或输入模型名称")
                else:
                    # 翻译
                    result = translate_to_cantonese(prompt, api_key, selected_model, base_url, slang_mode)

                    # 处理结果：区分标准模式和俚语模式
                    if slang_mode and isinstance(result, dict):
                        cantonese_standard = result.get("cantonese", "")
                        cantonese_slang = result.get("slang")
                        note = result.get("note", "")

                        # 更新消息状态为"生成标准语音"（粤拼在 generating_audio 阶段用 PyCantonese 生成）
                        st.session_state.messages[-1].update({
                            "status": "generating_audio",
                            "cantonese": cantonese_standard,
                            "cantonese_slang": cantonese_slang or "",
                            "jyutping": "",
                            "jyutping_slang": "",
                            "note": note
                        })

                        # 保存到当前对话并rerun显示"生成标准语音..."
                        if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                            current_id = st.session_state.current_conversation_id
                            if current_id in st.session_state.conversations:
                                st.session_state.conversations[current_id] = st.session_state.messages.copy()
                        st.rerun()
                    else:
                        # 标准模式：只显示翻译结果
                        cantonese = result if isinstance(result, str) else result.get("cantonese", "")

                        # 更新消息状态为"生成语音"
                        st.session_state.messages[-1].update({
                            "status": "generating_audio",
                            "cantonese": cantonese
                        })

                        # 保存到当前对话并rerun显示"生成标准语音..."
                        if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                            current_id = st.session_state.current_conversation_id
                            if current_id in st.session_state.conversations:
                                st.session_state.conversations[current_id] = st.session_state.messages.copy()
                        st.rerun()

    # 处理生成标准语音状态
    if st.session_state.messages and api_key:
        last_message = st.session_state.messages[-1]
        if last_message.get("role") == "assistant" and last_message.get("status") == "generating_audio":
            cantonese = last_message.get("cantonese", "")
            cantonese_slang = last_message.get("cantonese_slang", "")

            # 生成标准语音
            audio_standard = None
            jyutping = ""

            if cantonese and not is_error_message(str(cantonese)):
                jyutping = add_jyutping(cantonese)
                audio_standard = generate_audio(cantonese, selected_voice)
            else:
                jyutping = "（翻译失败）"

            # 检查是否有俚语需要生成语音
            if slang_mode and cantonese_slang and cantonese_slang != cantonese and not is_error_message(str(cantonese_slang)):
                # 更新状态为"生成俚语语音"
                st.session_state.messages[-1].update({
                    "status": "generating_slang_audio",
                    "jyutping": jyutping,
                    "audio_standard": audio_standard
                })
            else:
                # 没有俚语，直接完成
                st.session_state.messages[-1].update({
                    "status": "completed",
                    "jyutping": jyutping,
                    "audio_standard": audio_standard,
                    "cantonese_slang": "",
                    "jyutping_slang": "",
                    "has_slang": False,
                    "audio_slang": None
                })

            # 保存到当前对话
            if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                current_id = st.session_state.current_conversation_id
                if current_id in st.session_state.conversations:
                    st.session_state.conversations[current_id] = st.session_state.messages.copy()

            st.rerun()

    # 处理生成俚语语音状态
    if st.session_state.messages and api_key:
        last_message = st.session_state.messages[-1]
        if last_message.get("role") == "assistant" and last_message.get("status") == "generating_slang_audio":
            cantonese_slang = last_message.get("cantonese_slang", "")

            # 生成俚语语音
            audio_slang = None
            jyutping_slang = ""
            has_slang = False

            if cantonese_slang and not is_error_message(str(cantonese_slang)):
                jyutping_slang = add_jyutping(cantonese_slang)
                audio_slang = generate_audio(cantonese_slang, selected_voice)
                has_slang = True

            # 更新消息为完成状态
            st.session_state.messages[-1].update({
                "status": "completed",
                "has_slang": has_slang,
                "audio_slang": audio_slang
            })

            # 保存到当前对话
            if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
                current_id = st.session_state.current_conversation_id
                if current_id in st.session_state.conversations:
                    st.session_state.conversations[current_id] = st.session_state.messages.copy()

            st.rerun()

    # 使用说明
    if not st.session_state.messages:
        st.info("""
        ### 💡 使用说明

        1. **配置Base URL**: 输入OpenAI兼容的API Base URL（例如: https://api.siliconflow.cn/v1）
        2. **配置API Key**: 在左侧输入对应API的 Key
        3. **选择模型**: 系统会自动从Base URL获取可用模型列表，也可以手动输入模型名称
        4. **选择配音**: 可选择不同的香港语音
        5. **开始对话**: 在下方输入普通话，AI会：
           - 🗣️ 翻译成地道粤语
           - 📝 自动标注粤拼（使用PyCantonese）
           - 🔊 生成香港口音语音（使用Edge-TTS）

        ### 示例

        **输入**: 你在干什么？
        **输出**: 你做紧乜嘢呀？
        **粤拼**: 你(nei5) 做紧(zou6gan2) 乜嘢(mat1je5) 呀(aa3)
        """)

# ============ 标签页2: 粤语解释 ============
with tab2:
    st.markdown("### 💬 粤语解释工具")
    st.markdown("输入粤语句子或词汇，AI会用普通话为您详细解释其含义、用法和文化背景。")

    # 输入区域
    # 初始化清空标志
    if "clear_explain" not in st.session_state:
        st.session_state.clear_explain = False

    # 如果需要清空，设置默认值为空
    default_explain = "" if st.session_state.clear_explain else st.session_state.get("explain_text", "")

    cantonese_query = st.text_area(
        "输入粤语（词汇或句子）",
        value=default_explain,
        placeholder="例如：乜嘢、搵食、你做緊乜？",
        height=100,
        key="explain_input"
    )

    # 保存输入内容
    st.session_state.explain_text = cantonese_query

    # 重置清空标志
    if st.session_state.clear_explain:
        st.session_state.clear_explain = False

    col1, col2 = st.columns([1, 4])
    with col1:
        explain_btn = st.button("💭 获取解释", use_container_width=True, type="primary")
    with col2:
        if st.button("🗑️ 清空", use_container_width=True, key="clear_explain_btn"):
            st.session_state.clear_explain = True
            st.rerun()

    # 处理解释请求
    if explain_btn and cantonese_query.strip():
        if not api_key:
            st.error("❌ 请先在侧边栏输入 API Key")
        elif not selected_model:
            st.error("❌ 请先选择或输入模型名称")
        else:
            with st.spinner("正在生成解释..."):
                # 构建提示词
                system_prompt = "You are a Cantonese language expert. Explain Cantonese words and phrases in Mandarin Chinese with detailed cultural context."
                user_prompt = f"""请用普通话详细解释以下粤语内容：

粤语：{cantonese_query.strip()}

请包括：
1. **字面意思**：逐字或逐词的字面含义
2. **实际含义**：在日常对话中的真实意思
3. **使用场景**：什么情况下使用这个表达
4. **文化背景**：相关的文化或历史背景（如有）
5. **普通话对应**：对应的普通话说法
6. **例句**：用粤语举1-2个实际使用例子，并附上普通话翻译

请用清晰、通俗易懂的普通话解释。"""

                # 调用API
                try:
                    base_url_normalized = base_url.rstrip('/')
                    if not base_url_normalized.endswith('/v1'):
                        base_url_normalized = base_url_normalized + '/v1'

                    url = base_url_normalized.rstrip('/') + '/chat/completions'
                    headers = {
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json"
                    }

                    data = {
                        "model": selected_model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt}
                        ],
                        "temperature": 0.7,
                        "max_tokens": 2048
                    }

                    response = requests.post(url, headers=headers, json=data, timeout=30)

                    if response.status_code == 200:
                        result_data = response.json()
                        explanation = result_data["choices"][0]["message"]["content"].strip()

                        # 显示结果
                        st.markdown("#### 📖 AI 解释")
                        st.markdown(explanation)
                        st.success("✅ 解释生成完成！")
                    else:
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

                        st.error(f"❌ API错误 (HTTP {response.status_code}): {error_detail}")
                except Exception as e:
                    st.error(f"❌ 请求失败: {str(e)}")

    # 使用说明
    if not cantonese_query or not explain_btn:
        st.info("""
        ### 💡 使用说明

        1. 在上方文本框输入您想了解的粤语词汇或句子
        2. 点击"获取解释"按钮
        3. AI会用普通话详细解释这个粤语表达
        4. 包括含义、用法、文化背景等信息

        ### 示例

        **输入**: 乜嘢
        **解释**: AI会告诉您"乜嘢"的意思是"什么"，以及如何使用

        **输入**: 你做緊乜？
        **解释**: AI会解释这句话的意思是"你在做什么？"，并提供使用场景

        ### 适用场景

        - 不理解某个粤语词汇的含义
        - 想知道粤语俚语的文化背景
        - 学习粤语日常用语
        - 了解粤语与普通话的对应关系
        """)

# 清空对话按钮（在侧边栏，不在标签页内）
if st.sidebar.button("🗑️ 清空对话历史"):
    cleanup_audio_files()  # 清理音频文件
    AUDIO_FILES.clear()  # 清空跟踪列表
    st.session_state.messages = []
    # 同时清空当前对话的历史记录
    if "current_conversation_id" in st.session_state and "conversations" in st.session_state:
        current_id = st.session_state.current_conversation_id
        if current_id in st.session_state.conversations:
            st.session_state.conversations[current_id] = []
    st.rerun()
