"""
语音生成服务模块（Edge-TTS，粤语常用 zh-HK-*）

环境变量（可选）：
- TTS_AUDIO_MAX_AGE_SECONDS：磁盘上 mp3 保留最长时间，超时自动删除。默认 1800（30 分钟）。
"""
import edge_tts
import os
import uuid
from pathlib import Path
from typing import Optional


def _max_age_seconds() -> int:
    return int(os.environ.get("TTS_AUDIO_MAX_AGE_SECONDS", "1800"))


# 与 main.py 中 STATIC_DIR 一致：backend/static/audio
_BACKEND_ROOT = Path(__file__).resolve().parent.parent
AUDIO_DIR = _BACKEND_ROOT / "static" / "audio"
AUDIO_DIR.mkdir(parents=True, exist_ok=True)


async def generate_audio(text: str, voice: str = "zh-HK-HiuMaanNeural") -> str:
    """
    使用edge-tts异步生成语音

    Args:
        text: 要转换的文本
        voice: 语音选择

    Returns:
        生成的音频文件路径
    """
    try:
        # 生成唯一文件名
        filename = f"{uuid.uuid4()}.mp3"
        file_path = AUDIO_DIR / filename

        # 生成语音
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(str(file_path))

        return str(file_path)
    except Exception as e:
        raise Exception(f"语音生成失败: {str(e)}")


def cleanup_old_audio_files(max_age_seconds: Optional[int] = None) -> int:
    """
    删除 AUDIO_DIR 下超过保留时间的 .mp3 文件。

    Args:
        max_age_seconds: 最大存活秒数；默认读环境变量 TTS_AUDIO_MAX_AGE_SECONDS（默认 1800）。

    Returns:
        删除的文件数量。
    """
    import time

    limit = max_age_seconds if max_age_seconds is not None else _max_age_seconds()
    removed = 0
    try:
        now = time.time()
        for audio_file in AUDIO_DIR.glob("*.mp3"):
            if not os.path.exists(audio_file):
                continue
            if now - os.path.getmtime(audio_file) > limit:
                os.remove(audio_file)
                removed += 1
    except Exception as e:
        print(f"清理音频文件失败: {e}")
    return removed


async def list_hk_tts_voices() -> list[dict]:
    """返回 zh-HK 区域 Edge-TTS 音色列表。"""
    all_voices = await edge_tts.list_voices()
    out: list[dict] = []
    for v in all_voices:
        loc = v.get("Locale") or ""
        if not loc.startswith("zh-HK"):
            continue
        out.append(
            {
                "short_name": v.get("ShortName", ""),
                "locale": loc,
                "gender": v.get("Gender", ""),
                "friendly_name": v.get("FriendlyName", ""),
            }
        )
    out.sort(key=lambda x: x["short_name"])
    return out
